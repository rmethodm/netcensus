public struct AssessmentDatabases: Sendable {
    public var cve: CVESnapshot
    public var firmware: FirmwareCatalog

    public init(cve: CVESnapshot, firmware: FirmwareCatalog) {
        self.cve = cve
        self.firmware = firmware
    }

    public static func bundled() -> AssessmentDatabases {
        AssessmentDatabases(cve: .bundled(), firmware: .bundled())
    }
}

public enum HostAssessor: Sendable {
    public static func assess(
        _ host: HostDraft,
        databases: AssessmentDatabases,
        credentials: [ScanCredential] = []
    ) async -> HostDraft {
        var result = HygieneProvider.assess(host)
        result = CVEMatchProvider.assess(result, snapshot: databases.cve)
        result = FirmwareProvider.assess(result, catalog: databases.firmware)
        result = await SNMPProvider.assess(result, credentials: credentials)
        result = await SSHCheck.assess(result, credentials: credentials)
        result = await HTTPBasicCheck.assess(result, credentials: credentials)
        return result
    }
}
