import Foundation

public actor LiveScanEngine: ScanEngine {
    private var cancelled = false

    public init() {}

    public func availableScopes() async -> [NetworkScopeDraft] {
        InterfaceEnumerator().ipv4Scopes().filter(\.isAssessable)
    }

    public func cancel() async {
        cancelled = true
    }

    public func events(for configuration: ScanConfiguration) async -> AsyncStream<ScanEvent> {
        AsyncStream { continuation in
            let task = Task {
                await self.run(configuration: configuration, continuation: continuation)
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func run(
        configuration: ScanConfiguration,
        continuation: AsyncStream<ScanEvent>.Continuation
    ) async {
        cancelled = false
        guard let session = DiscoverySession.make(
            configuration: configuration,
            continuation: continuation
        ) else {
            continuation.yield(.failed("Scope is not a private or link-local network, or is too large to enumerate."))
            continuation.finish()
            return
        }

        continuation.yield(.phaseChanged(.discovering))
        session.seedLocalHosts(configuration.scope.ipv4)

        async let mdns = MDNSDiscovery.browse(duration: .seconds(2))
        async let ssdp = SSDPDiscovery.search(timeout: .seconds(2))
        session.mergeARP(ARPTable.entries())
        session.mergeMDNS(await mdns)
        session.mergeSSDP(await ssdp)

        if Task.isCancelled || cancelled {
            continuation.yield(.cancelled)
            continuation.finish()
            return
        }

        await probe(session: session, configuration: configuration)
        session.mergeARP(ARPTable.entries())

        if Task.isCancelled || cancelled {
            continuation.yield(.cancelled)
            continuation.finish()
            return
        }

        continuation.yield(.phaseChanged(.fingerprinting))
        await fingerprint(session: session, configuration: configuration)

        if Task.isCancelled || cancelled {
            continuation.yield(.cancelled)
            continuation.finish()
            return
        }

        continuation.yield(.phaseChanged(.assessing))
        await assess(session: session, credentials: configuration.credentials)

        continuation.yield(.phaseChanged(.completed))
        continuation.yield(
            .completed(
                ScanSummary(
                    hostCount: session.hostCount,
                    findingCount: session.findingCount,
                    status: .completed
                )
            )
        )
        continuation.finish()
    }

    private func probe(session: DiscoverySession, configuration: ScanConfiguration) async {
        let targets = session.cidr.usableHosts()
        let limiter = ProbeRateLimiter(maxInFlight: 32, perSecond: configuration.rateLimitPerSecond)
        let ports = configuration.profile.discoveryTCPPorts
        session.progress(completed: 0, total: targets.count)
        var completed = 0
        await withTaskGroup(of: HostDraft?.self) { group in
            for address in targets {
                group.addTask {
                    if Task.isCancelled { return nil }
                    return await limiter.withPermit {
                        await HostProber.probe(address, ports: ports)
                    }
                }
            }
            for await result in group {
                completed += 1
                if completed == 1 || completed % 8 == 0 || completed == targets.count {
                    session.progress(completed: completed, total: targets.count)
                }
                if let host = result {
                    session.emit(host)
                }
                if Task.isCancelled || cancelled {
                    group.cancelAll()
                    break
                }
            }
        }
    }

    private func fingerprint(session: DiscoverySession, configuration: ScanConfiguration) async {
        let hosts = session.snapshot()
        let limiter = ProbeRateLimiter(maxInFlight: 8, perSecond: configuration.rateLimitPerSecond)
        let ports = configuration.profile.fingerprintTCPPorts
        let oui = OUILookup.bundled()
        session.progress(completed: 0, total: max(hosts.count, 1))
        var completed = 0
        await withTaskGroup(of: HostDraft.self) { group in
            for host in hosts {
                group.addTask {
                    await limiter.withPermit {
                        await HostFingerprinter.fingerprint(host, extraPorts: ports, oui: oui)
                    }
                }
            }
            for await host in group {
                completed += 1
                session.progress(completed: completed, total: hosts.count)
                session.emitUpdate(host)
                if Task.isCancelled || cancelled {
                    group.cancelAll()
                    break
                }
            }
        }
    }

    private func assess(session: DiscoverySession, credentials: [ScanCredential]) async {
        let hosts = session.snapshot()
        let databases = AssessmentDatabases.bundled()
        session.progress(completed: 0, total: max(hosts.count, 1))
        var completed = 0
        await withTaskGroup(of: HostDraft.self) { group in
            for host in hosts {
                group.addTask {
                    await HostAssessor.assess(
                        host,
                        databases: databases,
                        credentials: credentials
                    )
                }
            }
            for await host in group {
                completed += 1
                session.progress(completed: completed, total: hosts.count)
                session.emitUpdate(host)
                if Task.isCancelled || cancelled {
                    group.cancelAll()
                    break
                }
            }
        }
    }
}

private final class DiscoverySession: @unchecked Sendable {
    let cidr: IPv4CIDR
    let continuation: AsyncStream<ScanEvent>.Continuation
    private var accumulator = HostAccumulator()

    var hostCount: Int { accumulator.allHosts().count }

    var findingCount: Int {
        accumulator.allHosts().reduce(0) { $0 + $1.findings.count }
    }

    func snapshot() -> [HostDraft] { accumulator.allHosts() }

    init(cidr: IPv4CIDR, continuation: AsyncStream<ScanEvent>.Continuation) {
        self.cidr = cidr
        self.continuation = continuation
    }

    static func make(
        configuration: ScanConfiguration,
        continuation: AsyncStream<ScanEvent>.Continuation
    ) -> DiscoverySession? {
        guard let cidr = try? IPv4CIDR(configuration.scope.cidr), cidr.isAssessable, cidr.canEnumerateHosts else {
            return nil
        }
        return DiscoverySession(cidr: cidr, continuation: continuation)
    }

    func seedLocalHosts(_ localIP: String?) {
        if let localIP, let address = IPv4Address(localIP), cidr.contains(address) {
            emit(
                HostDraft(
                    identity: HostIdentity(ipv4: localIP, hostname: Host.current().localizedName),
                    deviceClass: .computer,
                    flags: HostFlags(discoveryMethods: ["local"], isThisMac: true)
                )
            )
        }
        if let gateway = cidr.host(at: 1)?.dotted {
            emit(
                HostDraft(
                    identity: HostIdentity(ipv4: gateway),
                    deviceClass: .router,
                    flags: HostFlags(discoveryMethods: ["cidr"], isGateway: true)
                )
            )
        }
    }

    func mergeARP(_ entries: [ARPEntry]) {
        for entry in entries where isUsableARP(entry) {
            emit(
                HostDraft(
                    identity: HostIdentity(ipv4: entry.ipv4, mac: entry.mac),
                    flags: HostFlags(discoveryMethods: ["arp"])
                )
            )
        }
    }

    func mergeMDNS(_ records: [MDNSRecord]) {
        for record in records {
            guard let ip = record.ipv4, inScope(ip) else { continue }
            emit(
                HostDraft(
                    identity: HostIdentity(ipv4: ip, hostname: record.hostname),
                    flags: HostFlags(discoveryMethods: ["mdns"]),
                    evidence: [EvidenceDraft(kind: .mdns, summary: record.serviceType, payload: record.hostname)]
                )
            )
        }
    }

    func mergeSSDP(_ replies: [SSDPReply]) {
        for reply in replies {
            guard let ip = reply.ipv4, inScope(ip) else { continue }
            emit(
                HostDraft(
                    identity: HostIdentity(ipv4: ip, vendor: reply.server),
                    flags: HostFlags(discoveryMethods: ["ssdp"]),
                    evidence: [
                        EvidenceDraft(
                            kind: .upnpXml,
                            summary: reply.searchTarget ?? "SSDP",
                            payload: reply.location ?? reply.usn ?? ""
                        ),
                    ]
                )
            )
        }
    }

    func emit(_ host: HostDraft) {
        continuation.yield(.hostDiscovered(accumulator.upsert(host)))
    }

    func emitUpdate(_ host: HostDraft) {
        continuation.yield(.hostUpdated(accumulator.upsert(host)))
    }

    func progress(completed: Int, total: Int) {
        continuation.yield(.progress(completed: completed, total: total))
    }

    private func inScope(_ ip: String) -> Bool {
        guard let address = IPv4Address(ip) else { return false }
        return cidr.contains(address)
    }

    private func isUsableARP(_ entry: ARPEntry) -> Bool {
        guard let address = IPv4Address(entry.ipv4), cidr.isUsableHost(address) else { return false }
        if let mac = MACAddress(entry.mac), mac.isBroadcast || mac.isMulticast { return false }
        return true
    }
}
