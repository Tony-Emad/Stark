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
        let context = LAContext()
        context.interactionNotAllowed = true
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        // Loading identity data at launch must never interrupt the user with
        // a system Keychain dialog. Explicit authorization remains available
        // through LocalAuthentication when Stark needs it.
        query[kSecUseAuthenticationContext] = context

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound || status == errSecInteractionNotAllowed || status == errSecAuthFailed {
            return nil
        }
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
    var featurePrints: [Data] { identity?.featurePrints ?? [] }

    func add(featurePrint: Data) throws {
        var candidate = identity ?? FaceIdentity(id: UUID(), createdAt: Date(), featurePrints: [])
        candidate.featurePrints.append(featurePrint)
        try persist(candidate)
        identity = candidate
    }

    func clear() throws {
        try keychain.delete(account: account)
        identity = nil
    }

    private func reload() {
        do {
            guard let data = try keychain.load(account: account) else { return }
            identity = try JSONDecoder().decode(FaceIdentity.self, from: data)
        } catch {
            identity = nil
        }
    }

    private func persist(_ identity: FaceIdentity) throws {
        let data = try JSONEncoder().encode(identity)
        try keychain.save(data, account: account)
    }
}
