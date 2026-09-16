import Foundation
import Security

public struct TLSCertSummary: Sendable, Equatable {
    public var commonName: String?
    public var issuer: String?
    public var notBefore: Date?
    public var notAfter: Date?
    public var subjectAltNames: [String]

    public init(
        commonName: String? = nil,
        issuer: String? = nil,
        notBefore: Date? = nil,
        notAfter: Date? = nil,
        subjectAltNames: [String] = []
    ) {
        self.commonName = commonName
        self.issuer = issuer
        self.notBefore = notBefore
        self.notAfter = notAfter
        self.subjectAltNames = subjectAltNames
    }

    public var isExpired: Bool {
        guard let notAfter else { return false }
        return notAfter < Date()
    }

    public var summaryLine: String {
        let cn = commonName ?? "unknown CN"
        let expiry = notAfter?.formatted(date: .abbreviated, time: .omitted) ?? "unknown expiry"
        return "\(cn) issued by \(issuer ?? "unknown"); not after \(expiry)"
    }

    public static func from(certificate: SecCertificate) -> TLSCertSummary {
        var cfName: CFString?
        SecCertificateCopyCommonName(certificate, &cfName)
        let commonName = cfName as String?
        let values = SecCertificateCopyValues(certificate, nil, nil) as? [String: Any]
        return TLSCertSummary(
            commonName: commonName,
            issuer: stringValue(values, key: kSecOIDX509V1IssuerName as String),
            notBefore: dateValue(values, key: kSecOIDX509V1ValidityNotBefore as String),
            notAfter: dateValue(values, key: kSecOIDX509V1ValidityNotAfter as String),
            subjectAltNames: altNames(values)
        )
    }

    private static func stringValue(_ values: [String: Any]?, key: String) -> String? {
        guard let entry = values?[key] as? [String: Any] else { return nil }
        if let name = entry[kSecPropertyKeyValue as String] as? String { return name }
        if let parts = entry[kSecPropertyKeyValue as String] as? [[String: Any]] {
            let joined = parts.compactMap { $0[kSecPropertyKeyValue as String] as? String }.joined(separator: ", ")
            return joined.isEmpty ? nil : joined
        }
        return nil
    }

    private static func dateValue(_ values: [String: Any]?, key: String) -> Date? {
        guard let entry = values?[key] as? [String: Any] else { return nil }
        if let date = entry[kSecPropertyKeyValue as String] as? Date { return date }
        if let number = entry[kSecPropertyKeyValue as String] as? NSNumber {
            return Date(timeIntervalSinceReferenceDate: number.doubleValue)
        }
        return nil
    }

    private static func altNames(_ values: [String: Any]?) -> [String] {
        guard let entry = values?[kSecOIDSubjectAltName as String] as? [String: Any],
              let parts = entry[kSecPropertyKeyValue as String] as? [[String: Any]]
        else {
            return []
        }
        return parts.compactMap { $0[kSecPropertyKeyValue as String] as? String }
    }
}
