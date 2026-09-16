public struct HostDriftSnapshot: Sendable, Equatable, Identifiable {
    public var ipv4: String?
    public var mac: String?
    public var hostname: String?
    public var ports: [Int]

    public init(ipv4: String? = nil, mac: String? = nil, hostname: String? = nil, ports: [Int] = []) {
        self.ipv4 = ipv4
        self.mac = mac
        self.hostname = hostname
        self.ports = ports
    }

    public var id: String { key }

    public var key: String {
        if let mac, let canonical = MACAddress(mac)?.canonical {
            return "mac:\(canonical)"
        }
        if let ipv4 {
            return "ip:\(ipv4)"
        }
        return "name:\(hostname ?? "")"
    }

    public var portSet: Set<Int> { Set(ports) }
}

public enum DriftStatus: String, Sendable, CaseIterable {
    case appeared
    case disappeared
    case changed
    case unchanged

    public var title: String {
        switch self {
        case .appeared: "New"
        case .disappeared: "Gone"
        case .changed: "Changed"
        case .unchanged: "Unchanged"
        }
    }
}

public struct DriftRow: Sendable, Equatable, Identifiable {
    public var snapshot: HostDriftSnapshot
    public var status: DriftStatus

    public var id: String { snapshot.key }

    public init(snapshot: HostDriftSnapshot, status: DriftStatus) {
        self.snapshot = snapshot
        self.status = status
    }
}

public enum InventoryDiffer: Sendable {
    public static func diff(
        previous: [HostDriftSnapshot],
        current: [HostDriftSnapshot]
    ) -> [DriftRow] {
        var previousByKey: [String: HostDriftSnapshot] = [:]
        for item in previous { previousByKey[item.key] = item }
        var currentByKey: [String: HostDriftSnapshot] = [:]
        for item in current { currentByKey[item.key] = item }
        var rows: [DriftRow] = []
        for (key, host) in currentByKey {
            if let prior = previousByKey[key] {
                let status: DriftStatus = prior.portSet == host.portSet ? .unchanged : .changed
                rows.append(DriftRow(snapshot: host, status: status))
            } else {
                rows.append(DriftRow(snapshot: host, status: .appeared))
            }
        }
        for (key, host) in previousByKey where currentByKey[key] == nil {
            rows.append(DriftRow(snapshot: host, status: .disappeared))
        }
        return rows.sorted { $0.snapshot.key < $1.snapshot.key }
    }
}

extension HostDraft {
    public var driftSnapshot: HostDriftSnapshot {
        HostDriftSnapshot(
            ipv4: identity.ipv4,
            mac: identity.mac,
            hostname: identity.hostname,
            ports: services.map(\.port)
        )
    }
}
