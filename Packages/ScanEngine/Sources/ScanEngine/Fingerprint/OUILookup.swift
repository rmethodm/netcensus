import Foundation

public struct OUILookup: Sendable {
    private let vendors: [String: String]

    public init(vendors: [String: String]) {
        var normalized: [String: String] = [:]
        for (key, value) in vendors {
            let prefix = Self.normalizePrefix(key)
            if !prefix.isEmpty {
                normalized[prefix] = value
            }
        }
        self.vendors = normalized
    }

    public init(text: String) {
        var vendors: [String: String] = [:]
        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            let parts = line.split(maxSplits: 1, whereSeparator: \.isWhitespace)
            guard parts.count == 2 else { continue }
            let prefix = Self.normalizePrefix(String(parts[0]))
            let name = String(parts[1]).trimmingCharacters(in: .whitespaces)
            if !prefix.isEmpty, !name.isEmpty {
                vendors[prefix] = name
            }
        }
        self.vendors = vendors
    }

    public static func bundled() -> OUILookup {
        if let url = Bundle.module.url(forResource: "oui-common", withExtension: "txt"),
           let text = try? String(contentsOf: url, encoding: .utf8) {
            return OUILookup(text: text)
        }
        return OUILookup(vendors: [:])
    }

    public func vendor(forMAC mac: String) -> String? {
        guard let address = MACAddress(mac) else { return nil }
        return vendors[address.ouiPrefix]
    }

    public var count: Int { vendors.count }

    static func normalizePrefix(_ raw: String) -> String {
        let hex = raw.filter(\.isHexDigit)
        let padded = String((hex + "000000").prefix(12))
        return MACAddress(padded)?.ouiPrefix ?? ""
    }
}
