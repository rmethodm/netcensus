import Foundation

public struct SoftwareVersion: Sendable, Comparable, Equatable {
    public var parts: [Int]

    public init?(_ raw: String) {
        let parsed = raw
            .split(separator: ".")
            .map { chunk in chunk.prefix { $0.isNumber } }
            .compactMap { Int($0) }
        guard !parsed.isEmpty else { return nil }
        parts = parsed
    }

    public static func < (lhs: SoftwareVersion, rhs: SoftwareVersion) -> Bool {
        let count = max(lhs.parts.count, rhs.parts.count)
        for index in 0..<count {
            let left = index < lhs.parts.count ? lhs.parts[index] : 0
            let right = index < rhs.parts.count ? rhs.parts[index] : 0
            if left != right { return left < right }
        }
        return false
    }

    public static func extract(from text: String) -> SoftwareVersion? {
        let pattern = #"(\d+\.\d+(?:\.\d+){0,3})"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text)
        else {
            return nil
        }
        return SoftwareVersion(String(text[range]))
    }
}
