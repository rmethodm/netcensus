import Foundation
import ScanEngine

public actor FakeScanEngine: ScanEngine {
    private let stepDelay: Duration
    private var cancelled = false

    public init(stepDelay: Duration = .milliseconds(180)) {
        self.stepDelay = stepDelay
    }

    public func availableScopes() async -> [NetworkScopeDraft] {
        let enumerator = InterfaceEnumerator()
        return enumerator.demoScopeIfEmpty(enumerator.ipv4Scopes())
    }

    public func cancel() async {
        cancelled = true
    }

    public func events(for configuration: ScanConfiguration) async -> AsyncStream<ScanEvent> {
        AsyncStream { continuation in
            let task = Task {
                await self.run(configuration: configuration, continuation: continuation)
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func run(
        configuration: ScanConfiguration,
        continuation: AsyncStream<ScanEvent>.Continuation
    ) async {
        cancelled = false
        let cidr = (try? IPv4CIDR(configuration.scope.cidr)) ?? (try? IPv4CIDR("192.168.1.0/24"))
        guard let cidr else {
            continuation.yield(.failed("Invalid CIDR \(configuration.scope.cidr)"))
            continuation.finish()
            return
        }

        let hosts = FixtureCatalog.hosts(in: cidr)
        continuation.yield(.phaseChanged(.discovering))
        continuation.yield(.progress(completed: 0, total: hosts.count))

        var discovered: [HostDraft] = []
        for (index, var host) in hosts.enumerated() {
            if Task.isCancelled || cancelled {
                continuation.yield(.cancelled)
                continuation.finish()
                return
            }
            await pause()
            host.flags.discoveryMethods = uniqueMethods(host.flags.discoveryMethods, adding: "fixture")
            continuation.yield(.hostDiscovered(stripped(host)))
            discovered.append(host)
            continuation.yield(.progress(completed: index + 1, total: hosts.count))
        }

        continuation.yield(.phaseChanged(.fingerprinting))
        for host in discovered {
            if Task.isCancelled || cancelled {
                continuation.yield(.cancelled)
                continuation.finish()
                return
            }
            await pause()
            continuation.yield(.hostUpdated(withoutFindings(host)))
        }

        continuation.yield(.phaseChanged(.assessing))
        var findingCount = 0
        for host in discovered {
            if Task.isCancelled || cancelled {
                continuation.yield(.cancelled)
                continuation.finish()
                return
            }
            await pause()
            findingCount += host.findings.count
            continuation.yield(.hostUpdated(host))
        }

        continuation.yield(.phaseChanged(.completed))
        continuation.yield(
            .completed(ScanSummary(hostCount: discovered.count, findingCount: findingCount, status: .completed))
        )
        continuation.finish()
    }

    private func pause() async {
        guard stepDelay != .zero else { return }
        try? await Task.sleep(for: stepDelay)
    }

    private func stripped(_ host: HostDraft) -> HostDraft {
        var copy = host
        copy.services = []
        copy.evidence = []
        copy.findings = []
        return copy
    }

    private func withoutFindings(_ host: HostDraft) -> HostDraft {
        var copy = host
        copy.findings = []
        return copy
    }

    private func uniqueMethods(_ existing: [String], adding extra: String) -> [String] {
        var methods = existing
        if !methods.contains(extra) {
            methods.append(extra)
        }
        return methods
    }
}
