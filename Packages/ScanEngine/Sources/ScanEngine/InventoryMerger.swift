import Foundation

public struct DeviceSnapshot: Sendable, Equatable {
    public var id: UUID
    public var primaryMAC: String?
    public var ipv4: String?
    public var vendor: String?
    public var hostname: String?
    public var lastSeenAt: Date

    public init(
        id: UUID,
        primaryMAC: String? = nil,
        ipv4: String? = nil,
        vendor: String? = nil,
        hostname: String? = nil,
        lastSeenAt: Date
    ) {
        self.id = id
        self.primaryMAC = primaryMAC
        self.ipv4 = ipv4
        self.vendor = vendor
        self.hostname = hostname
        self.lastSeenAt = lastSeenAt
    }
}

public struct InventoryMerger: Sendable {
    public var matchWindow: TimeInterval

    public init(matchWindow: TimeInterval = 7 * 24 * 60 * 60) {
        self.matchWindow = matchWindow
    }

    public func matchingDeviceID(
        for host: HostDraft,
        in devices: [DeviceSnapshot],
        now: Date = .now
    ) -> UUID? {
        if let mac = canonicalMAC(host.identity.mac) {
            if let match = devices.first(where: { canonicalMAC($0.primaryMAC) == mac }) {
                return match.id
            }
        }

        guard let ipv4 = host.identity.ipv4 else { return nil }
        let vendor = normalized(host.identity.vendor)
        let hostname = normalized(host.identity.hostname)

        return devices.first { device in
            guard device.ipv4 == ipv4 else { return false }
            guard now.timeIntervalSince(device.lastSeenAt) <= matchWindow else { return false }
            let vendorMatch = vendor != nil && vendor == normalized(device.vendor)
            let hostMatch = hostname != nil && hostname == normalized(device.hostname)
            return vendorMatch && hostMatch
        }?.id
    }

    private func canonicalMAC(_ raw: String?) -> String? {
        raw.flatMap(MACAddress.init)?.canonical
    }

    private func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.isEmpty ? nil : trimmed
    }
}
