import Foundation

public enum HostFingerprinter: Sendable {
    public static func fingerprint(
        _ host: HostDraft,
        extraPorts: [UInt16],
        oui: OUILookup
    ) async -> HostDraft {
        guard let ip = host.identity.ipv4 else { return host }
        var result = host
        applyOUI(to: &result, oui: oui)
        await scanPorts(ip: ip, extraPorts: extraPorts, into: &result)
        await enrichServices(ip: ip, host: &result)
        await enrichUPnP(into: &result)
        result.deviceClass = DeviceClassGuess.guess(result)
        return result
    }

    private static func applyOUI(to host: inout HostDraft, oui: OUILookup) {
        guard host.identity.vendor == nil, let mac = host.identity.mac,
              let vendor = oui.vendor(forMAC: mac)
        else { return }
        host.identity.vendor = vendor
        host.evidence.append(
            EvidenceDraft(kind: .note, summary: "OUI vendor", payload: vendor)
        )
    }

    private static func scanPorts(ip: String, extraPorts: [UInt16], into host: inout HostDraft) async {
        let known = Set(host.services.map(\.port))
        for port in extraPorts where !known.contains(Int(port)) {
            if Task.isCancelled { return }
            if await TCPProbe.canConnect(host: ip, port: port) {
                host.services.append(
                    ServiceDraft(port: Int(port), protocolGuess: protocolGuess(port))
                )
            }
        }
    }

    private static func enrichServices(ip: String, host: inout HostDraft) async {
        for index in host.services.indices {
            if Task.isCancelled { return }
            let port = UInt16(host.services[index].port)
            let useTLS = isTLS(port)
            let sendHTTP = isHTTP(port)
            let payload = sendHTTP ? HTTPResponseParser.getRequest(host: ip) : nil
            let exchange = await TCPExchange.transact(
                host: ip,
                port: port,
                useTLS: useTLS,
                payload: payload
            )
            apply(exchange, to: &host, index: index, port: port)
        }
    }

    private static func apply(
        _ exchange: TCPExchangeResult,
        to host: inout HostDraft,
        index: Int,
        port: UInt16
    ) {
        let useTLS = isTLS(port)
        let sendHTTP = isHTTP(port)
        if !exchange.body.isEmpty {
            host.services[index].banner = String(exchange.body.prefix(512))
        }
        if sendHTTP || exchange.body.contains("HTTP/") {
            let response = HTTPResponseParser.parse(exchange.body)
            if let server = response.server {
                host.services[index].product = host.services[index].product ?? server
                host.evidence.append(EvidenceDraft(kind: .httpHeader, summary: "Server", payload: server))
            }
            if let title = response.title {
                host.identity.hostname = host.identity.hostname ?? title
                host.evidence.append(EvidenceDraft(kind: .httpBodyExcerpt, summary: "HTML title", payload: title))
            }
            if host.services[index].protocolGuess == nil {
                host.services[index].protocolGuess = useTLS ? "https" : "http"
            }
        }
        if let cert = exchange.certificate {
            let prefix = cert.isExpired ? "EXPIRED: " : ""
            host.evidence.append(
                EvidenceDraft(
                    kind: .certificate,
                    summary: prefix + cert.summaryLine,
                    payload: prefix + cert.summaryLine
                )
            )
            if host.identity.hostname == nil { host.identity.hostname = cert.commonName }
        }
        if host.services[index].protocolGuess == nil, exchange.body.hasPrefix("SSH-") {
            host.services[index].protocolGuess = "ssh"
            host.flags.osGuess = host.flags.osGuess ?? String(exchange.body.prefix(80))
        }
    }

    private static func enrichUPnP(into host: inout HostDraft) async {
        let urls = host.evidence.compactMap { UPnPDeviceParser.locationURL(from: $0.payload) }
        for url in urls.prefix(3) {
            if Task.isCancelled { return }
            guard let ip = url.host, IPv4Address(ip) != nil else { continue }
            let port = UInt16(url.port ?? 80)
            let path = url.path.isEmpty ? "/" : url.path
            let exchange = await TCPExchange.transact(
                host: ip,
                port: port,
                useTLS: url.scheme == "https",
                payload: HTTPResponseParser.getRequest(host: ip, path: path)
            )
            let info = UPnPDeviceParser.parse(exchange.body)
            guard !info.isEmpty else { continue }
            host.identity.hostname = host.identity.hostname ?? info.friendlyName
            host.identity.vendor = host.identity.vendor ?? info.manufacturer
            host.flags.firmwareGuess = host.flags.firmwareGuess ?? info.modelNumber
            host.evidence.append(
                EvidenceDraft(
                    kind: .upnpXml,
                    summary: info.modelName ?? info.friendlyName ?? "UPnP device",
                    payload: exchange.body
                )
            )
        }
    }

    private static func isHTTP(_ port: UInt16) -> Bool {
        [80, 631, 5000, 8000, 8080, 8443, 443, 5001].contains(port)
    }

    private static func isTLS(_ port: UInt16) -> Bool {
        [443, 8443, 5001, 993, 995].contains(port)
    }

    private static func protocolGuess(_ port: UInt16) -> String? {
        Self.portNames[port]
    }

    private static let portNames: [UInt16: String] = [
        21: "ftp",
        22: "ssh",
        23: "telnet",
        80: "http",
        139: "smb",
        443: "https",
        445: "smb",
        548: "afp",
        631: "ipp",
        3389: "rdp",
        5000: "http",
        5001: "https",
        5900: "vnc",
        8000: "http",
        8080: "http",
        8443: "https",
        9100: "jetdirect",
    ]
}
