import Foundation

enum HaystackMatch: Sendable {
    static func containsToken(_ token: String, in haystack: String) -> Bool {
        let token = token.lowercased()
        let haystack = haystack.lowercased()
        guard !token.isEmpty else { return false }
        if token.contains(where: { $0 == " " }) {
            return haystack.contains(token)
        }
        var searchStart = haystack.startIndex
        while let range = haystack.range(of: token, range: searchStart..<haystack.endIndex) {
            if hasBoundary(in: haystack, around: range) {
                return true
            }
            searchStart = range.upperBound
        }
        return false
    }

    /// Version must sit next to the product token (`Apache/2.4.49`, `OpenSSH_9.8`).
    static func version(in haystack: String, near token: String) -> SoftwareVersion? {
        let haystack = haystack.lowercased()
        let token = token.lowercased()
        var searchStart = haystack.startIndex
        while let range = haystack.range(of: token, range: searchStart..<haystack.endIndex) {
            let windowEnd = haystack.index(range.upperBound, offsetBy: 24, limitedBy: haystack.endIndex)
                ?? haystack.endIndex
            let window = String(haystack[range.upperBound..<windowEnd])
            if let version = SoftwareVersion.extract(from: window) {
                let gap = window.prefix(while: { !$0.isNumber }).count
                if gap <= 3 { return version }
            }
            searchStart = range.upperBound
        }
        return nil
    }

    private static func hasBoundary(in haystack: String, around range: Range<String.Index>) -> Bool {
        let beforeOK: Bool
        if range.lowerBound == haystack.startIndex {
            beforeOK = true
        } else {
            let previous = haystack[haystack.index(before: range.lowerBound)]
            beforeOK = !previous.isLetter && !previous.isNumber
        }
        let afterOK: Bool
        if range.upperBound == haystack.endIndex {
            afterOK = true
        } else {
            let next = haystack[range.upperBound]
            afterOK = !next.isLetter && !next.isNumber
        }
        return beforeOK && afterOK
    }
}
