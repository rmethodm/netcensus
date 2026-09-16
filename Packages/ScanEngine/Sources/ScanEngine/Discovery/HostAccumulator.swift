public struct HostAccumulator: Sendable {
    private var hosts: [String: HostDraft] = [:]

    public init() {}

    public mutating func upsert(_ incoming: HostDraft) -> HostDraft {
        guard let ip = incoming.identity.ipv4 else { return incoming }
        if let existing = hosts[ip] {
            let merged = Self.merging(existing, with: incoming)
            hosts[ip] = merged
            return merged
        }
        hosts[ip] = incoming
        return incoming
    }

    public func allHosts() -> [HostDraft] {
        hosts.values.sorted { ($0.identity.ipv4 ?? "") < ($1.identity.ipv4 ?? "") }
    }

    public static func merging(_ existing: HostDraft, with incoming: HostDraft) -> HostDraft {
        var result = existing
        result.identity.ipv4 = existing.identity.ipv4 ?? incoming.identity.ipv4
        result.identity.ipv6 = existing.identity.ipv6 ?? incoming.identity.ipv6
        result.identity.mac = existing.identity.mac ?? incoming.identity.mac
        result.identity.hostname = existing.identity.hostname ?? incoming.identity.hostname
        result.identity.vendor = existing.identity.vendor ?? incoming.identity.vendor
        if result.deviceClass == .unknown {
            result.deviceClass = incoming.deviceClass
        }
        result.flags.osGuess = existing.flags.osGuess ?? incoming.flags.osGuess
        result.flags.firmwareGuess = existing.flags.firmwareGuess ?? incoming.flags.firmwareGuess
        result.flags.latencyMS = existing.flags.latencyMS ?? incoming.flags.latencyMS
        result.flags.isGateway = existing.flags.isGateway || incoming.flags.isGateway
        result.flags.isThisMac = existing.flags.isThisMac || incoming.flags.isThisMac
        result.flags.discoveryMethods = unique(existing.flags.discoveryMethods + incoming.flags.discoveryMethods)
        result.flags.cpes = unique(existing.flags.cpes + incoming.flags.cpes)
        result.services = mergeServices(existing.services, incoming.services)
        result.evidence = existing.evidence + incoming.evidence.filter { extra in
            !existing.evidence.contains { $0.payload == extra.payload && $0.kind == extra.kind }
        }
        result.findings = existing.findings + incoming.findings.filter { extra in
            !existing.findings.contains { $0.id == extra.id }
        }
        return result
    }

    private static func unique(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        return values.filter { seen.insert($0).inserted }
    }

    private static func mergeServices(_ lhs: [ServiceDraft], _ rhs: [ServiceDraft]) -> [ServiceDraft] {
        var keyed: [String: ServiceDraft] = [:]
        for service in lhs + rhs {
            let key = "\(service.transport.rawValue):\(service.port)"
            if let existing = keyed[key] {
                var merged = existing
                merged.banner = existing.banner ?? service.banner
                merged.protocolGuess = existing.protocolGuess ?? service.protocolGuess
                keyed[key] = merged
            } else {
                keyed[key] = service
            }
        }
        return keyed.values.sorted { $0.port < $1.port }
    }
}
