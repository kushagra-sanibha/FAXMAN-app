import CoreGraphics

/// An 8-bit grayscale image, row-major, top-left origin.
nonisolated struct GrayImage: Sendable {
    let width: Int
    let height: Int
    let pixels: [UInt8]

    @inline(__always)
    func value(atX x: CGFloat, y: CGFloat) -> CGFloat? {
        let xi = Int(x.rounded()), yi = Int(y.rounded())
        guard xi >= 0, yi >= 0, xi < width, yi < height else { return nil }
        return CGFloat(pixels[yi * width + xi])
    }
}

/// Snaps a rough page outline (from Vision's document segmentation) onto the
/// paper's real edges, the way dedicated scanner apps do.
///
/// For each side of the rough outline it scans perpendicular to that side —
/// far inward, a little outward — for points where the image steps from
/// brighter (paper) to darker (background), then fits the straight line most
/// of those points agree on. A candidate line only counts if it really
/// separates paper from background: the strip just inside must be brighter
/// than the strip just outside. Ruled lines and text inside the page have
/// paper on both sides, so they never qualify; and when segmentation has
/// swallowed some white table around the page, the true edge is found
/// inward.
///
/// Returns nil (keep the rough outline) whenever any side can't be found
/// confidently. Pure and deterministic, so it's unit-testable.
nonisolated enum PageEdgeRefiner {
    struct Configuration {
        /// How far inside the rough side to look, as a fraction of the image's
        /// long side. On a phone, Vision's outline is already close to the
        /// page, so this is a small correction: a wide search lands on ruled
        /// lines, margins or the binding inside the page.
        var inwardRange: CGFloat = 0.03
        /// How far outside the rough side to look.
        var outwardRange: CGFloat = 0.03
        var samplesPerSide = 24
        /// Smallest brightness step (0–255) that counts as an edge point.
        var minimumStep: CGFloat = 6
        /// Inside-minus-outside brightness a side must show (0–255).
        var minimumContrast: CGFloat = 5
        /// Share of samples that must agree on a side.
        var minimumSupport: CGFloat = 0.35
        var inlierDistance: CGFloat = 1.5
        /// cos of the largest angle (6°) a snapped side may differ from the rough side.
        var minimumParallel: CGFloat = 0.9945
        /// Distance (fraction of the long side) at which an edge's score halves.
        var proximityScale: CGFloat = 0.04
        /// A candidate counts as "strong" at this share of the best score;
        /// the innermost strong one wins (the top page, not the stack under it).
        var strongShare: CGFloat = 0.3
        /// Edge candidates kept per scan line.
        var peaksPerSample = 12
    }

    /// - Parameters:
    ///   - rough: the rough outline, normalized 0…1, top-left origin, in `image`'s orientation.
    /// - Returns: the snapped outline in the same space and how many of its
    ///   four sides sit on a real paper edge (the rest kept the rough line), or nil.
    static func refine(_ rough: NormalizedQuad, in image: GrayImage, configuration: Configuration = Configuration()) -> Refinement? {
        let w = CGFloat(image.width), h = CGFloat(image.height)
        guard w > 8, h > 8 else { return nil }
        let corners = rough.points.map { CGPoint(x: $0.x * w, y: $0.y * h) }
        let center = CGPoint(x: corners.map(\.x).reduce(0, +) / 4, y: corners.map(\.y).reduce(0, +) / 4)
        let longSide = max(w, h)

        // Each side snaps on its own; a side with no confident edge keeps the
        // rough line, so one blurry side doesn't throw away the others.
        var lines: [Line] = []
        var snappedSides = 0
        for side in 0..<4 {
            let a = corners[side], b = corners[(side + 1) % 4]
            if let line = findEdge(
                from: a, to: b, center: center,
                inward: configuration.inwardRange * longSide, outward: configuration.outwardRange * longSide,
                image: image, configuration: configuration
            ) {
                lines.append(line)
                snappedSides += 1
            } else if let rough = Line(through: a, b) {
                lines.append(rough)
            } else {
                return nil
            }
        }
        guard snappedSides > 0 else { return nil }

        var snapped: [CGPoint] = []
        for corner in 0..<4 {
            // Corner `corner` sits between the side ending there and the side starting there.
            guard let point = lines[(corner + 3) % 4].intersection(with: lines[corner]) else { return nil }
            snapped.append(point)
        }

        // A corner that moved far more than the rest — at a tilt, one side
        // latching onto a crease, a shadow, or a page's own binding right
        // next to the real edge — combines into one bad intersection while
        // its neighbours land cleanly. On an otherwise well-fit outline,
        // Vision's own rough corner is the safer bet there than that
        // intersection, which is how a corner ends up visibly clipped even
        // though the other three sides hug the page correctly.
        let displacement = zip(snapped, corners).map { hypot($0.x - $1.x, $0.y - $1.y) }
        let middleTwo = displacement.sorted()[1...2]
        let typical = middleTwo.reduce(0, +) / 2
        for corner in 0..<4 where displacement[corner] > max(typical * 2.5, longSide * 0.01) {
            snapped[corner] = corners[corner]
        }

        let reach = (configuration.inwardRange + configuration.outwardRange) * longSide * 1.6
        guard zip(snapped, corners).allSatisfy({ hypot($0.x - $1.x, $0.y - $1.y) <= reach }) else { return nil }
        let quad = NormalizedQuad(
            topLeft: CGPoint(x: snapped[0].x / w, y: snapped[0].y / h),
            topRight: CGPoint(x: snapped[1].x / w, y: snapped[1].y / h),
            bottomRight: CGPoint(x: snapped[2].x / w, y: snapped[2].y / h),
            bottomLeft: CGPoint(x: snapped[3].x / w, y: snapped[3].y / h)
        )
        guard quad.isValid, quad.area >= rough.area * 0.25,
              quad.points.allSatisfy({ (-0.02...1.02).contains($0.x) && (-0.02...1.02).contains($0.y) }) else { return nil }
        return Refinement(quad: quad, snappedSides: snappedSides)
    }

    struct Refinement: Sendable {
        let quad: NormalizedQuad
        /// 4 = every side is a real paper edge.
        let snappedSides: Int
    }

    // MARK: - One side

    private struct EdgePoint {
        let sample: Int
        /// Distance outside the rough side (negative = inside).
        let offset: CGFloat
        let point: CGPoint
    }

    private static func findEdge(
        from a: CGPoint, to b: CGPoint, center: CGPoint,
        inward: CGFloat, outward: CGFloat, image: GrayImage, configuration: Configuration
    ) -> Line? {
        let length = hypot(b.x - a.x, b.y - a.y)
        guard length > 8 else { return nil }
        let along = CGVector(dx: (b.x - a.x) / length, dy: (b.y - a.y) / length)
        var normal = CGVector(dx: -along.dy, dy: along.dx)
        let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        if (mid.x - center.x) * normal.dx + (mid.y - center.y) * normal.dy < 0 {
            normal = CGVector(dx: -normal.dx, dy: -normal.dy)
        }

        // Candidate edge points: brightness drops going outward.
        let count = configuration.samplesPerSide
        var points: [EdgePoint] = []
        for i in 0..<count {
            let t = 0.1 + 0.8 * CGFloat(i) / CGFloat(count - 1)
            let base = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
            func sample(_ d: CGFloat) -> CGFloat? {
                image.value(atX: base.x + normal.dx * d, y: base.y + normal.dy * d)
            }
            var peaks: [(d: CGFloat, step: CGFloat)] = []
            var previousStep: CGFloat = 0
            var d = -inward
            while d <= outward {
                if let inside = sample(d - 1), let outside = sample(d + 1) {
                    let step = inside - outside
                    if step >= configuration.minimumStep, step >= previousStep {
                        if let last = peaks.last, d - last.d <= 1.5 {
                            if step > last.step { peaks[peaks.count - 1] = (d, step) }
                        } else {
                            peaks.append((d, step))
                        }
                    }
                    previousStep = step
                }
                d += 1
            }
            // Generous: on lined paper the ruled lines are stronger steps than a
            // soft page edge; the contrast test below throws them out later.
            for peak in peaks.sorted(by: { $0.step > $1.step }).prefix(configuration.peaksPerSample) {
                points.append(EdgePoint(sample: i, offset: peak.d, point: CGPoint(x: base.x + normal.dx * peak.d, y: base.y + normal.dy * peak.d)))
            }
        }
        guard points.count >= 2 else { return nil }

        // Straight lines most samples agree on that truly separate paper from
        // background. Every pairing of points half a side apart whose line
        // runs nearly parallel to the rough side is tried — systematic, so a
        // faint page edge among many ruled lines is never skipped by chance.
        var bySample = Array(repeating: [EdgePoint](), count: count)
        for point in points { bySample[point.sample].append(point) }
        let spacing = length * 0.8 / CGFloat(count - 1)
        let half = count / 2
        let maxOffsetChange = tan(6 * CGFloat.pi / 180) * spacing * CGFloat(half) + 1.5
        var candidates: [(line: Line, score: CGFloat, outward: CGFloat)] = []
        var hypotheses: [(EdgePoint, EdgePoint)] = []
        for s in 0..<(count - half) {
            for p in bySample[s] {
                for q in bySample[s + half] where abs(p.offset - q.offset) <= maxOffsetChange {
                    hypotheses.append((p, q))
                }
            }
        }
        for (p, q) in hypotheses {
            guard let line = Line(through: p.point, q.point) else { continue }

            var supported = Set<Int>()
            var inliers: [CGPoint] = []
            for candidate in points where line.distance(to: candidate.point) <= configuration.inlierDistance {
                supported.insert(candidate.sample)
                inliers.append(candidate.point)
            }
            let support = CGFloat(supported.count) / CGFloat(count)
            guard support >= configuration.minimumSupport else { continue }

            let fitted = Line(fitting: inliers) ?? line
            // The real edge runs nearly parallel to the rough side; a steep
            // line is something else (spiral holes, a crease, a table streak).
            guard abs(fitted.direction.dx * along.dx + fitted.direction.dy * along.dy) >= configuration.minimumParallel else { continue }
            let contrast = Self.contrast(across: fitted, at: inliers, normal: normal, image: image)
            guard contrast >= configuration.minimumContrast else { continue }
            // How far outside the rough side this line runs (negative = inside).
            let onLine = fitted.closestPoint(to: mid)
            let outward = (onLine.x - mid.x) * normal.dx + (onLine.y - mid.y) * normal.dy
            let proximity = 1 / (1 + abs(outward) / (configuration.proximityScale * max(CGFloat(image.width), CGFloat(image.height))))
            candidates.append((fitted, support * contrast * proximity, outward))
        }
        // Among strong candidates, the innermost: on a notebook or a stack of
        // sheets that's the top page's edge, not the pages underneath — the
        // way dedicated scanner apps outline only the page on top.
        guard let bestScore = candidates.map(\.score).max() else { return nil }
        return candidates
            .filter { $0.score >= bestScore * configuration.strongShare }
            .min { $0.outward < $1.outward }?
            .line
    }

    /// Mean brightness just inside the line minus just outside it.
    private static func contrast(across line: Line, at points: [CGPoint], normal: CGVector, image: GrayImage) -> CGFloat {
        var inside: CGFloat = 0, outside: CGFloat = 0, n: CGFloat = 0
        for point in points {
            let p = line.closestPoint(to: point)
            for k in stride(from: CGFloat(3), through: 7, by: 2) {
                guard let i = image.value(atX: p.x - normal.dx * k, y: p.y - normal.dy * k),
                      let o = image.value(atX: p.x + normal.dx * k, y: p.y + normal.dy * k) else { continue }
                inside += i
                outside += o
                n += 1
            }
        }
        return n > 0 ? (inside - outside) / n : 0
    }
}

/// A 2D line through `point` along unit `direction`.
private nonisolated struct Line {
    let point: CGPoint
    let direction: CGVector

    init?(through a: CGPoint, _ b: CGPoint) {
        let length = hypot(b.x - a.x, b.y - a.y)
        guard length > 1e-6 else { return nil }
        point = a
        direction = CGVector(dx: (b.x - a.x) / length, dy: (b.y - a.y) / length)
    }

    /// Total least squares fit.
    init?(fitting points: [CGPoint]) {
        guard points.count >= 2 else { return nil }
        let n = CGFloat(points.count)
        let mx = points.map(\.x).reduce(0, +) / n, my = points.map(\.y).reduce(0, +) / n
        var sxx: CGFloat = 0, syy: CGFloat = 0, sxy: CGFloat = 0
        for p in points {
            let dx = p.x - mx, dy = p.y - my
            sxx += dx * dx
            syy += dy * dy
            sxy += dx * dy
        }
        let angle = 0.5 * atan2(2 * sxy, sxx - syy)
        point = CGPoint(x: mx, y: my)
        direction = CGVector(dx: cos(angle), dy: sin(angle))
    }

    func distance(to p: CGPoint) -> CGFloat {
        abs((p.x - point.x) * direction.dy - (p.y - point.y) * direction.dx)
    }

    func closestPoint(to p: CGPoint) -> CGPoint {
        let t = (p.x - point.x) * direction.dx + (p.y - point.y) * direction.dy
        return CGPoint(x: point.x + direction.dx * t, y: point.y + direction.dy * t)
    }

    func intersection(with other: Line) -> CGPoint? {
        let cross = direction.dx * other.direction.dy - direction.dy * other.direction.dx
        guard abs(cross) > 0.05 else { return nil } // nearly parallel sides
        let dx = other.point.x - point.x, dy = other.point.y - point.y
        let t = (dx * other.direction.dy - dy * other.direction.dx) / cross
        return CGPoint(x: point.x + direction.dx * t, y: point.y + direction.dy * t)
    }
}
