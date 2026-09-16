import Foundation
import Testing
@testable import ScanEngine

struct FindingValidatorTests {
    @Test func cveRequiresIdentifier() {
        let finding = FindingDraft(
            source: "cve-match",
            title: "Something",
            detail: "x",
            classification: FindingClassification(severity: .high, category: .cve),
            remediation: "Update",
            evidenceIDs: [UUID()]
        )
        #expect(throws: FindingValidationError.cveMissingIdentifier) {
            try finding.validate()
        }
    }

    @Test func nonUnidentifiedRequiresEvidence() {
        let finding = FindingDraft(
            source: "hygiene",
            title: "Telnet",
            detail: "open",
            classification: FindingClassification(severity: .high, category: .exposure),
            remediation: "Disable Telnet",
            evidenceIDs: []
        )
        #expect(throws: FindingValidationError.missingEvidence) {
            try finding.validate()
        }
    }

    @Test func unidentifiedMayHaveNoEvidence() throws {
        let finding = FindingDraft(
            source: "firmware",
            title: "Unknown",
            detail: "none",
            classification: FindingClassification(severity: .info, category: .unidentified),
            remediation: "Identify manually",
            evidenceIDs: []
        )
        try finding.validate()
    }
}
