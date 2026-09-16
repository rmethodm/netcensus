import Foundation

public enum HTTPBasicAuth: Sendable {
    public static func authorizationValue(username: String, password: String) -> String {
        let token = Data("\(username):\(password)".utf8).base64EncodedString()
        return "Basic \(token)"
    }

    public static func getRequest(host: String, username: String, password: String, path: String = "/") -> Data {
        let auth = authorizationValue(username: username, password: password)
        return Data(
            """
            GET \(path) HTTP/1.0\r
            Host: \(host)\r
            Authorization: \(auth)\r
            User-Agent: Scanner/0.1\r
            Accept: */*\r
            Connection: close\r
            \r
            """.utf8
        )
    }
}

public enum HTTPBasicCheck: Sendable {
    public static func assess(_ host: HostDraft, credentials: [ScanCredential]) async -> HostDraft {
        guard let ip = host.identity.ipv4 else { return host }
        let matches = credentials.filter { $0.kind == .httpBasic && $0.matches(hostIP: ip) }
        guard let credential = matches.first,
              let username = credential.username, !username.isEmpty,
              !credential.secret.isEmpty
        else {
            return host
        }
        var updated = host
        var ports: [(UInt16, Bool)] = []
        if host.openPort(80) != nil { ports.append((80, false)) }
        if host.openPort(443) != nil { ports.append((443, true)) }
        for (port, useTLS) in ports.prefix(2) {
            let payload = HTTPBasicAuth.getRequest(
                host: ip,
                username: username,
                password: credential.secret
            )
            let exchange = await TCPExchange.transact(
                host: ip,
                port: port,
                useTLS: useTLS,
                payload: payload
            )
            let response = HTTPResponseParser.parse(exchange.body)
            guard let status = response.statusCode, (200..<300).contains(status) else { continue }
            updated.evidence.append(
                EvidenceDraft(
                    kind: .httpHeader,
                    summary: "HTTP basic succeeded on \(port)",
                    payload: "status \(status) \(response.server ?? "") \(response.title ?? "")"
                )
            )
            if let title = response.title {
                updated.identity.hostname = updated.identity.hostname ?? title
            }
            break
        }
        return updated
    }
}
