import Foundation
import Security

/// The only identifier anything on our servers is tied to: a random UUID in
/// the Keychain. Not the advertising identifier, never shown to the user,
/// and linkable to an account later without losing data.
enum AnonymousIdentity {
    private static let service = "app.faxit.anonymous-id"
    private static let account = "anonymous-id"

    /// Created on first use.
    static var current: String {
        if let existing = read() { return existing }
        let created = UUID().uuidString
        write(created)
        return created
    }

    /// After "Delete my data": the app starts over as a fresh install.
    static func reset() {
        SecItemDelete(baseQuery as CFDictionary)
    }

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    private static func read() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func write(_ value: String) {
        var item = baseQuery
        item[kSecValueData as String] = Data(value.utf8)
        // Device-only: never migrates through a backup to another phone.
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }
}
