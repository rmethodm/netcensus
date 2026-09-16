import Darwin

public struct InterfaceEnumerator: Sendable {
    public init() {}

    public func ipv4Scopes() -> [NetworkScopeDraft] {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return [] }
        defer { freeifaddrs(ifaddr) }

        var scopes: [NetworkScopeDraft] = []
        var pointer: UnsafeMutablePointer<ifaddrs>? = first

        while let current = pointer {
            pointer = current.pointee.ifa_next
            if let scope = scope(from: current.pointee) {
                scopes.append(scope)
            }
        }

        return scopes
    }

    public func demoScopeIfEmpty(_ scopes: [NetworkScopeDraft]) -> [NetworkScopeDraft] {
        if scopes.contains(where: \.isAssessable) { return scopes }
        return [
            NetworkScopeDraft(
                interfaceName: "demo0",
                cidr: "192.168.1.0/24",
                ipv4: "192.168.1.10",
                estimatedHostCount: 254,
                isAssessable: true,
                displayName: "Demo (no assessable interface)"
            ),
        ]
    }

    private func scope(from interface: ifaddrs) -> NetworkScopeDraft? {
        let flags = Int32(interface.ifa_flags)
        guard flags & IFF_UP != 0, flags & IFF_LOOPBACK == 0 else { return nil }
        guard let addrPtr = interface.ifa_addr, addrPtr.pointee.sa_family == sa_family_t(AF_INET) else {
            return nil
        }
        guard let maskPtr = interface.ifa_netmask else { return nil }

        let name = Self.string(fromCString: interface.ifa_name)
        guard let ipv4 = dottedIPv4(addrPtr) else { return nil }
        guard let mask = dottedIPv4(maskPtr) else { return nil }
        guard let prefix = IPv4CIDR.prefixLength(netmask: mask) else { return nil }
        guard let address = IPv4Address(ipv4), let cidr = try? IPv4CIDR(network: address, prefixLength: prefix) else {
            return nil
        }

        return NetworkScopeDraft(
            interfaceName: name,
            cidr: cidr.cidrString,
            ipv4: ipv4,
            estimatedHostCount: cidr.hostCount,
            isAssessable: cidr.isAssessable,
            displayName: name
        )
    }

    private func dottedIPv4(_ sa: UnsafePointer<sockaddr>) -> String? {
        sa.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { pointer in
            var addr = pointer.pointee.sin_addr
            var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            guard inet_ntop(AF_INET, &addr, &buffer, socklen_t(INET_ADDRSTRLEN)) != nil else {
                return nil
            }
            return Self.string(fromCStringBuffer: buffer)
        }
    }

    private static func string(fromCStringBuffer buffer: [CChar]) -> String {
        let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }

    private static func string(fromCString pointer: UnsafePointer<CChar>?) -> String {
        guard let pointer else { return "" }
        var bytes: [UInt8] = []
        var index = 0
        while pointer[index] != 0 {
            bytes.append(UInt8(bitPattern: pointer[index]))
            index += 1
        }
        return String(decoding: bytes, as: UTF8.self)
    }
}
