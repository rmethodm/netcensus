import Foundation
import ScanEngine

struct CredentialVault {
    private let defaults: UserDefaults
    private let keychain: KeychainStore
    private let key = "credentialMetadata"

    init(defaults: UserDefaults = .standard, keychain: KeychainStore = KeychainStore()) {
        self.defaults = defaults
        self.keychain = keychain
    }

    func list() -> [ScanCredential] {
        guard let data = defaults.data(forKey: key),
              let records = try? JSONDecoder().decode([ScanCredential].self, from: data)
        else {
            return []
        }
        return records.map { record in
            var copy = record
            copy.secret = ""
            return copy
        }
    }

    func resolved() -> [ScanCredential] {
        list().map { record in
            var copy = record
            copy.secret = keychain.load(account: account(for: record.id)) ?? ""
            return copy
        }
    }

    func save(_ credential: ScanCredential) throws {
        var records = list()
        records.removeAll { $0.id == credential.id }
        var stored = credential
        let secret = stored.secret
        stored.secret = ""
        records.append(stored)
        let data = try JSONEncoder().encode(records)
        defaults.set(data, forKey: key)
        if !secret.isEmpty {
            try keychain.save(account: account(for: credential.id), secret: secret)
        }
    }

    func remove(_ id: UUID) {
        var records = list()
        records.removeAll { $0.id == id }
        if let data = try? JSONEncoder().encode(records) {
            defaults.set(data, forKey: key)
        }
        keychain.delete(account: account(for: id))
    }

    private func account(for id: UUID) -> String {
        "cred.\(id.uuidString)"
    }
}
