import Foundation
import Security

public actor KeychainSessionVault: AuthenticationSessionStoring {
    private let service: String
    private let account: String

    public init(
        service: String = "com.CodingKovs.BagLog.authentication",
        account: String = "baglog-session"
    ) {
        self.service = service
        self.account = account
    }

    public func load() throws -> AuthenticationSession? {
        var query = itemQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess,
              let data = result as? Data else {
            throw AuthenticationError.secureStorage
        }

        do {
            return try JSONDecoder().decode(AuthenticationSession.self, from: data)
        } catch {
            throw AuthenticationError.secureStorage
        }
    }

    public func save(_ session: AuthenticationSession) throws {
        let data: Data
        do {
            data = try JSONEncoder().encode(session)
        } catch {
            throw AuthenticationError.secureStorage
        }

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let updateStatus = SecItemUpdate(
            itemQuery as CFDictionary,
            attributes as CFDictionary
        )

        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var item = itemQuery
            attributes.forEach { item[$0.key] = $0.value }
            guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else {
                throw AuthenticationError.secureStorage
            }
        default:
            throw AuthenticationError.secureStorage
        }
    }

    public func clear() throws {
        let status = SecItemDelete(itemQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AuthenticationError.secureStorage
        }
    }

    private var itemQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: false
        ]
    }
}
