import Foundation
import Security

enum KeychainError: LocalizedError {
    case unhandled(OSStatus)
    case invalidData

    var errorDescription: String? {
        switch self {
        case .unhandled(let status):
            "Keychain error \(status)"
        case .invalidData:
            "Keychain item contained invalid data"
        }
    }
}

struct KeychainStore {
    let service = "ShakeTimer"

    func save(_ value: String, account: String) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if status == errSecItemNotFound {
            var newItem = query
            newItem[kSecValueData as String] = data
            let addStatus = SecItemAdd(newItem as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainError.unhandled(addStatus) }
            return
        }

        guard status == errSecSuccess else { throw KeychainError.unhandled(status) }
    }

    func load(account: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainError.unhandled(status) }
        guard let data = result as? Data, let value = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }
        return value
    }

    func delete(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandled(status)
        }
    }
}
