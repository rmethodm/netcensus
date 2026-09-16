public enum DeviceClassGuess: Sendable {
    public static func guess(_ host: HostDraft) -> DeviceClass {
        if host.deviceClass != .unknown { return host.deviceClass }
        let ports = Set(host.services.map(\.port))
        let haystack = [
            host.identity.vendor,
            host.identity.hostname,
            host.flags.osGuess,
        ].compactMap { $0 }.joined(separator: " ").lowercased()
        let types = host.evidence.map(\.summary).joined(separator: " ").lowercased()

        if ports.contains(9100) || ports.contains(631) || types.contains("_ipp") || types.contains("_printer") {
            return .printer
        }
        if haystack.contains("synology") || haystack.contains("qnap") || ports.contains(5000) || ports.contains(5001) {
            return .nas
        }
        if host.flags.isGateway || haystack.contains("router") || types.contains("internetgateway") {
            return .router
        }
        if haystack.contains("vmware") || haystack.contains("virtualbox") {
            return .virtualMachine
        }
        if ports.contains(22) || ports.contains(5900) || ports.contains(3389) {
            return .computer
        }
        if types.contains("_googlecast") || types.contains("_airplay") || haystack.contains("esp") {
            return .iot
        }
        if ports.contains(80) || ports.contains(443) {
            return .unknown
        }
        return .unknown
    }
}
