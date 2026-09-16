# Scanner — Data Model

**Last Updated**: 2026-09-15

## Entities

### NetworkScope

**Purpose**: What was authorized and scanned.

**Attributes**:

- `id`: UUID
- `interfaceName`: String (e.g. `en0`)
- `cidr`: String (e.g. `192.168.1.0/24`)
- `authorizationAcknowledgedAt`: Date
- `authorizationTextVersion`: String (copy version the user agreed to)

### ScanRun

**Purpose**: One immutable execution.

**Attributes**:

- `id`: UUID
- `startedAt` / `finishedAt`: Date?
- `status`: enum `queued | running | paused | cancelled | failed | completed`
- `profile`: enum `quick | standard | full`
- `rateLimitPerSecond`: Int
- `engineVersion`: String
- `cveSnapshotVersion`: String
- `errorMessage`: String?

**Relationships**:

- `scope`: NetworkScope
- `hosts`: ScanHost (one-to-many)
- `findings`: Finding (one-to-many, also reachable via host)

### Device

**Purpose**: Stable inventory identity across runs.

**Attributes**:

- `id`: UUID
- `primaryMAC`: String? (canonical merge key)
- `ouiVendor`: String?
- `displayName`: String (user override or best hostname)
- `notes`: String
- `tags`: [String]
- `firstSeenAt` / `lastSeenAt`: Date
- `isIgnored`: Bool

**Relationships**:

- `observations`: ScanHost (one-to-many)
- `credentials`: CredentialRef (optional, one-to-many by host)

**Merge rule**: MAC (normalized) → else IPv4 + OUI + mDNS name within 7 days → else new Device.

### ScanHost

**Purpose**: This host as seen in this run (snapshot).

**Attributes**:

- `id`: UUID
- `ipv4` / `ipv6`: String?
- `mac`: String?
- `hostname`: String?
- `vendor`: String?
- `deviceClass`: enum `computer | phone | ap | iot | printer | nas | router | vm | unknown`
- `osGuess`: String?
- `firmwareGuess`: String?
- `cpe`: [String]
- `discoveryMethods`: [String] (arp, icmp, mdns, …)
- `latencyMS`: Double?
- `isGateway`: Bool
- `isThisMac`: Bool

**Relationships**:

- `run`: ScanRun
- `device`: Device
- `services`: Service
- `evidence`: Evidence
- `findings`: Finding

### Service

**Purpose**: Open port / protocol.

**Attributes**:

- `id`: UUID
- `port`: Int
- `transport`: enum `tcp | udp`
- `state`: enum `open | closed | filtered | unknown`
- `protocolGuess`: String? (ssh, http, …)
- `banner`: String? (truncated, 512 chars)
- `product` / `version`: String?

### Evidence

**Purpose**: Raw snippet backing identity or a finding.

**Attributes**:

- `id`: UUID
- `kind`: enum `banner | httpHeader | httpBodyExcerpt | upnpXml | cert | snmp | mdns | tls | note`
- `summary`: String
- `payload`: String (size-capped; binary as hex prefix)
- `collectedAt`: Date

### Finding

**Purpose**: One risk or gap.

**Attributes**:

- `id`: UUID
- `source`: String (provider id)
- `title`: String
- `detail`: String
- `severity`: enum `info | low | medium | high | critical`
- `cvss`: Double?
- `cveIDs`: [String]
- `cpes`: [String]
- `confidence`: enum `low | medium | high`
- `category`: enum `cve | firmware | missingUpdate | exposure | hygiene | unidentified`
- `remediation`: String (update / disable / restrict — never an exploit step)
- `status`: enum `open | acknowledged | ignored | resolved`
- `firstSeenRunID` / `lastSeenRunID`: UUID

**Validation**:

- Must reference ≥1 Evidence id **or** be `unidentified`
- `cve` category requires ≥1 CVE id
- payload/remediation must not contain shell metaploit-style commands we didn’t intend (lint in tests)

### CredentialRef

**Purpose**: Pointer to Keychain; no secret material in SwiftData.

**Attributes**:

- `id`: UUID
- `kind`: enum `snmpv2c | snmpv3 | sshPassword | sshKey | httpBasic`
- `accountLabel`: String (user visible)
- `keychainAccount`: String
- `scope`: enum `thisDevice | thisSubnet`
- `createdAt`: Date

### CVESnapshotMeta

**Purpose**: Which intelligence DB is loaded.

**Attributes**:

- `version`: String
- `generatedAt`: Date
- `cveCount`: Int
- `sha256`: String

## Relationships

```
NetworkScope 1 ── * ScanRun
ScanRun 1 ── * ScanHost ── 1 Device
ScanHost 1 ── * Service
ScanHost 1 ── * Evidence
ScanHost 1 ── * Finding
Device 1 ── * CredentialRef   (Keychain id only)
```

## Data Flow

1. Engine emits DTOs (`HostDraft`, `FindingDraft`).
2. Repository upserts `Device`, inserts `ScanRun` graph in one transaction.
3. UI queries `Device` (inventory) or `ScanRun` (a specific snapshot).
4. Diff: compare last two completed `ScanRun`s for the same `NetworkScope`.

## Persistence Strategy

- SwiftData main context for UI.
- Insert scan results on a background context; merge to view.
- CVE dataset: **not** SwiftData if large — read-only SQLite next to the app or in Application Support.

## Retention

- Default: keep all runs (professional log).
- Settings: prune runs older than N days, always keep latest per scope.
- User notes and ignored findings survive prune (they live on `Device` / `Finding.status`).

## Sample DTO (engine → app)

```swift
struct HostDraft: Sendable, Identifiable {
    var id: UUID
    var ipv4: String?
    var mac: String?
    var hostname: String?
    var discoveryMethods: [String]
    var services: [ServiceDraft]
    var evidence: [EvidenceDraft]
    var findings: [FindingDraft]
}
```

## Related Documents

- [architecture.md](./architecture.md)
- [features.md](./features.md)
