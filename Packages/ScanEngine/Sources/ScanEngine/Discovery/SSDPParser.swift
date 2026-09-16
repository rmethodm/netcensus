import Foundation

public struct SSDPReply: Sendable, Equatable {
    public var ipv4: String?
    public var location: String?
    public var server: String?
    public var usn: String?
    public var searchTarget: String?

    public init(
        ipv4: String? = nil,
        location: String? = nil,
        server: String? = nil,
        usn: String? = nil,
        searchTarget: String? = nil
    ) {
        self.ipv4 = ipv4
        self.location = location
        self.server = server
        self.usn = usn
        self.searchTarget = searchTarget
    }
}

public enum SSDPParser: Sendable {
    public static func parse(_ message: String) -> SSDPReply? {
        let normalized = message.replacingOccurrences(of: "\r\n", with: "\n")
        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false)
        guard let first = lines.first, first.uppercased().contains("HTTP") else { return nil }

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let separator = line.firstIndex(of: ":") else { continue }
            let name = line[..<separator].trimmingCharacters(in: .whitespaces).uppercased()
            let value = line[line.index(after: separator)...].trimmingCharacters(in: .whitespaces)
            headers[name] = String(value)
        }

        let location = headers["LOCATION"]
        let ipv4 = location.flatMap(ipv4FromURL) ?? headers["HOST"].flatMap(ipv4FromHost)
        guard ipv4 != nil || location != nil else { return nil }
        return SSDPReply(
            ipv4: ipv4,
            location: location,
            server: headers["SERVER"],
            usn: headers["USN"],
            searchTarget: headers["ST"]
        )
    }

    public static func searchPacket() -> Data {
        Data(
            """
            M-SEARCH * HTTP/1.1\r
            HOST: 239.255.255.250:1900\r
            MAN: \"ssdp:discover\"\r
            MX: 2\r
            ST: ssdp:all\r
            \r
            """.utf8
        )
    }

    private static func ipv4FromURL(_ value: String) -> String? {
        guard let url = URL(string: value), let host = url.host else { return ipv4FromHost(value) }
        return IPv4Address(host)?.dotted
    }

    private static func ipv4FromHost(_ value: String) -> String? {
        let host = value.split(separator: ":").first.map(String.init) ?? value
        return IPv4Address(host)?.dotted
    }
}
