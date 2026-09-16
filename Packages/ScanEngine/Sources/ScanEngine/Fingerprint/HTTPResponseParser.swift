import Foundation

public struct HTTPResponse: Sendable, Equatable {
    public var statusCode: Int?
    public var headers: [String: String]
    public var body: String

    public init(statusCode: Int? = nil, headers: [String: String] = [:], body: String = "") {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
    }

    public var server: String? { headers["server"] }
    public var contentType: String? { headers["content-type"] }
    public var title: String? { HTTPResponseParser.htmlTitle(body) }
}

public enum HTTPResponseParser: Sendable {
    public static func parse(_ raw: String) -> HTTPResponse {
        let normalized = raw.replacingOccurrences(of: "\r\n", with: "\n")
        guard let headerEnd = normalized.range(of: "\n\n") else {
            return HTTPResponse(body: String(normalized.prefix(8_192)))
        }
        let headerBlock = String(normalized[..<headerEnd.lowerBound])
        let body = String(normalized[headerEnd.upperBound...].prefix(8_192))
        let lines = headerBlock.split(separator: "\n", omittingEmptySubsequences: false)
        var status: Int?
        if let first = lines.first {
            let parts = first.split(separator: " ")
            if parts.count >= 2 { status = Int(parts[1]) }
        }
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let separator = line.firstIndex(of: ":") else { continue }
            let name = line[..<separator].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: separator)...].trimmingCharacters(in: .whitespaces)
            headers[name] = String(value)
        }
        return HTTPResponse(statusCode: status, headers: headers, body: body)
    }

    public static func htmlTitle(_ body: String) -> String? {
        let lower = body.lowercased()
        guard let start = lower.range(of: "<title"),
              let tagEnd = body.range(of: ">", range: start.upperBound..<body.endIndex),
              let close = lower.range(of: "</title>", range: tagEnd.upperBound..<body.endIndex)
        else {
            return nil
        }
        let title = body[tagEnd.upperBound..<close.lowerBound]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? nil : String(title.prefix(200))
    }

    public static func getRequest(host: String, path: String = "/") -> Data {
        Data(
            """
            GET \(path) HTTP/1.0\r
            Host: \(host)\r
            User-Agent: Scanner/0.1\r
            Accept: */*\r
            Connection: close\r
            \r
            """.utf8
        )
    }
}
