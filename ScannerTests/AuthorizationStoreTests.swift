import Foundation
import Testing
@testable import Scanner
import ScanEngine

struct AuthorizationStoreTests {
    @Test func authorizationIsScopedToInterfaceCIDRAndCopyVersion() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = AuthorizationStore(defaults: defaults)
        let scope = NetworkScopeDraft(
            interfaceName: "en0",
            cidr: "192.168.1.0/24",
            isAssessable: true
        )
        #expect(store.isAuthorized(scope) == false)
        store.authorize(scope)
        #expect(store.isAuthorized(scope))
        let other = NetworkScopeDraft(
            interfaceName: "en1",
            cidr: "192.168.1.0/24",
            isAssessable: true
        )
        #expect(store.isAuthorized(other) == false)
    }
}
