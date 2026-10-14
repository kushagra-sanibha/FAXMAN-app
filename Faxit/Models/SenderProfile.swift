import Foundation
import SwiftData

@Model
final class SenderProfile {
    var name: String
    var email: String
    var phone: String
    var company: String

    init(name: String = "", email: String = "", phone: String = "", company: String = "") {
        self.name = name
        self.email = email
        self.phone = phone
        self.company = company
    }
}
