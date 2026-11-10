import Foundation
import Security

final class KeychainService {
    private let serviceName = "com.tving.login-manager"

    /// 프로필 PIN의 Keychain 키. 계정 비밀번호(키 = UUID 문자열)와 같은 서비스에 둔다.
    static func profilePinKey(accountId: UUID, profileNo: Int) -> String {
        "\(accountId.uuidString).profile.\(profileNo)"
    }

    // MARK: - Account password (key = account UUID)

    @discardableResult
    func savePassword(_ password: String, forAccountId accountId: UUID) -> Bool {
        save(password, forKey: accountId.uuidString)
    }

    func loadPassword(forAccountId accountId: UUID) -> String? {
        load(forKey: accountId.uuidString)
    }

    @discardableResult
    func updatePassword(_ password: String, forAccountId accountId: UUID) -> Bool {
        update(password, forKey: accountId.uuidString)
    }

    func deletePassword(forAccountId accountId: UUID) {
        delete(forKey: accountId.uuidString)
    }

    func saveOrUpdate(password: String, forAccountId accountId: UUID) {
        saveOrUpdate(password, forKey: accountId.uuidString)
    }

    // MARK: - String-keyed secrets

    @discardableResult
    func save(_ secret: String, forKey key: String) -> Bool {
        guard let data = secret.data(using: .utf8) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
        ]

        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    func load(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    func update(_ secret: String, forKey key: String) -> Bool {
        guard let data = secret.data(using: .utf8) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
        ]

        let update: [String: Any] = [
            kSecValueData as String: data,
        ]

        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        return status == errSecSuccess
    }

    func delete(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
        ]

        SecItemDelete(query as CFDictionary)
    }

    func saveOrUpdate(_ secret: String, forKey key: String) {
        if load(forKey: key) != nil {
            update(secret, forKey: key)
        } else {
            save(secret, forKey: key)
        }
    }
}
