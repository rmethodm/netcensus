public enum HostProber: Sendable {
    public static func probe(_ address: IPv4Address, ports: [UInt16]) async -> HostDraft? {
        let ip = address.dotted
        let pinged = await ICMPPing.echo(address)
        var openPorts: [ServiceDraft] = []
        var methods: [String] = []
        if pinged { methods.append("icmp") }
        for port in ports {
            if Task.isCancelled { break }
            if await TCPProbe.canConnect(host: ip, port: port) {
                openPorts.append(ServiceDraft(port: Int(port), protocolGuess: guess(port)))
                if !methods.contains("tcp") {
                    methods.append("tcp")
                }
            }
        }
        guard pinged || !openPorts.isEmpty else { return nil }
        return HostDraft(
            identity: HostIdentity(ipv4: ip),
            flags: HostFlags(discoveryMethods: methods),
            services: openPorts
        )
    }

    private static func guess(_ port: UInt16) -> String? {
        switch port {
        case 22: "ssh"
        case 80: "http"
        case 443: "https"
        case 445: "smb"
        case 8080: "http"
        case 8443: "https"
        default: nil
        }
    }
}
