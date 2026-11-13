import Foundation
import LocalAuthentication
import Security

enum SecureStoreError: LocalizedError {
    case keychain(OSStatus)
    case invalidData

    var errorDescription: String? {
        switch self {
        case .keychain(let status): return "Keychain error (\(status))."
        case .invalidData: return "The saved Stark identity data is invalid."
        }
    }
}

final class KeychainStore {
    private let service = "com.stark.app"

    func save(_ data: Data, account: String) throws {
        let baseQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        SecItemDelete(baseQuery as CFDictionary)

        var query = baseQuery
        query[kSecValueData] = data
        query[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw SecureStoreError.keychain(status) }
    }

    func load(account: String) throws -> Data? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw SecureStoreError.keychain(status) }
        return result as? Data
    }

    func delete(account: String) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SecureStoreError.keychain(status)
        }
    }
}

struct FaceIdentity: Codable, Sendable {
    let id: UUID
    let createdAt: Date
    var featurePrints: [Data]
}

@MainActor
final class IdentityStore: ObservableObject {
    @Published private(set) var identity: FaceIdentity?

    private let keychain = KeychainStore()
    private let account = "face-identity"

    init() {
        reload()
    }

    var sampleCount: Int { identity?.featurePrints.count ?? 0 }
    var firstFeaturePrint: Data? { identity?.featurePrints.first }

    func add(featurePrint: Data) throws {
        if var identity {
            identity.featurePrints.append(featurePrint)
            self.identity = identity
        } else {
            identity = FaceIdentity(id: UUID(), createdAt: Date(), featurePrints: [featurePrint])
            self.identity = identity
        }
        try persist()
    }

    func clear() throws {
        identity = nil
        try keychain.delete(account: account)
    }

    private func reload() {
        do {
            guard let data = try keychain.load(account: account) else { return }
            identity = try JSONDecoder().decode(FaceIdentity.self, from: data)
        } catch {
            identity = nil
        }
    }

    private func persist() throws {
        guard let identity else { throw SecureStoreError.invalidData }
        let data = try JSONEncoder().encode(identity)
        try keychain.save(data, account: account)
    }
}
