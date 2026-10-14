import Foundation

/// What the user actually fills in on a cover page — separate from
/// `CoverPageStyle`, which only picks the visual template.
struct CoverPageDetails: Codable, Equatable {
    var to: String = ""
    var from: String = ""
    var subject: String = ""
    var comments: String = ""
    var isUrgent: Bool = false
    var pleaseReply: Bool = false
    var forReview: Bool = false
    var pleaseComment: Bool = false
}
