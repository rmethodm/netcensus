import Testing
import ScanEngine
import ScanEngineMocks

struct FakeScanEngineTests {
    @Test func fixtureCatalogIsWellFormed() throws {
        let cidr = try IPv4CIDR("10.8.0.0/24")
        let hosts = FixtureCatalog.hosts(in: cidr)
        #expect(hosts.count == 5)
        #expect(hosts.contains { $0.flags.isGateway })
        #expect(hosts.contains { $0.flags.isThisMac })
        #expect(hosts.allSatisfy { $0.identity.ipv4?.hasPrefix("10.8.0.") == true })
        for host in hosts {
            for finding in host.findings {
                try finding.validate()
            }
        }
    }

    @Test func engineCompletesAStandardRun() async throws {
        let engine = FakeScanEngine(stepDelay: .zero)
        let scope = NetworkScopeDraft(
            interfaceName: "en0",
            cidr: "192.168.1.0/24",
            isAssessable: true
        )
        var hosts: [HostDraft] = []
        var completed: ScanSummary?
        for await event in await engine.events(for: ScanConfiguration(scope: scope)) {
            switch event {
            case .hostUpdated(let host):
                hosts.removeAll { $0.id == host.id }
                hosts.append(host)
            case .hostDiscovered(let host):
                if !hosts.contains(where: { $0.id == host.id }) {
                    hosts.append(host)
                }
            case .completed(let summary):
                completed = summary
            case .failed(let message):
                Issue.record("engine failed: \(message)")
            default:
                break
            }
        }
        let summary = try #require(completed)
        #expect(summary.status == .completed)
        #expect(summary.hostCount == 5)
        #expect(summary.findingCount >= 3)
        #expect(hosts.count == 5)
    }

    @Test func cancelStopsTheStream() async {
        let engine = FakeScanEngine(stepDelay: .milliseconds(50))
        let scope = NetworkScopeDraft(
            interfaceName: "en0",
            cidr: "192.168.1.0/24",
            isAssessable: true
        )
        let stream = await engine.events(for: ScanConfiguration(scope: scope))
        var sawCancel = false
        let reader = Task {
            for await event in stream {
                if case .cancelled = event { return true }
            }
            return false
        }
        try? await Task.sleep(for: .milliseconds(20))
        await engine.cancel()
        sawCancel = await reader.value
        #expect(sawCancel)
    }
}

struct AuthorizationCopyTests {
    @Test func versionIsStableForPersistenceKeys() {
        #expect(!AuthorizationCopy.version.isEmpty)
        #expect(AuthorizationCopy.confirmation.contains("authorized"))
    }
}
