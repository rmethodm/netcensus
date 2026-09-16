import Foundation
import ScanEngine

struct AuthorizationStore {
    private let defaults: UserDefaults
    private let key = "authorizedScopes"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func isAuthorized(_ scope: NetworkScopeDraft) -> Bool {
        tokens().contains(token(for: scope))
    }

    func authorize(_ scope: NetworkScopeDraft) {
        var values = tokens()
        let item = token(for: scope)
        if !values.contains(item) {
            values.append(item)
            defaults.set(values, forKey: key)
        }
    }

    private func token(for scope: NetworkScopeDraft) -> String {
        "\(scope.interfaceName)|\(scope.cidr)|\(AuthorizationCopy.version)"
    }

    private func tokens() -> [String] {
        defaults.stringArray(forKey: key) ?? []
    }
}
