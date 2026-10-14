import Foundation

enum CoverPageStyle: String, Codable, CaseIterable, Identifiable {
    case none
    case minimal
    case professional
    case confidential

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: "None"
        case .minimal: "Minimal"
        case .professional: "Professional"
        case .confidential: "Confidential"
        }
    }
}
