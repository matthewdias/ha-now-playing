import KeychainAccess
import Foundation

protocol CredentialStore: Sendable {
    func save(key: String, value: String)
    func load(key: String) -> String?
    func delete(key: String)
}

struct KeychainCredentialStore: CredentialStore, @unchecked Sendable {
    private let keychain = Keychain(service: "com.matthewdias.ha-now-playing")
    func save(key: String, value: String) { keychain[key] = value }
    func load(key: String) -> String? { keychain[key] }
    func delete(key: String) { keychain[key] = nil }
}

struct UserDefaultsCredentialStore: CredentialStore, @unchecked Sendable {
    let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    func save(key: String, value: String) { defaults.set(value, forKey: key) }
    func load(key: String) -> String? { defaults.string(forKey: key) }
    func delete(key: String) { defaults.removeObject(forKey: key) }
}

#if DEBUG
let defaultCredentials: any CredentialStore = UserDefaultsCredentialStore()
#else
let defaultCredentials: any CredentialStore = KeychainCredentialStore()
#endif
