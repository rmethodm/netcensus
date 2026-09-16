# Scanner — Architecture

**Last Updated**: 2026-09-15

## Architecture Pattern

**Chosen Pattern**: MVVM (SwiftUI) + protocol-oriented **Scan Engine** (Swift actors) + repository layer.

### Rationale

- UI is a professional inventory/findings app — MVVM fits SwiftUI and keeps ViewModels testable.
- Discovery, banner grabs, and CVE matching are concurrent I/O. They belong in isolated actors, not ViewModels.
- Assessment rules must be unit-testable with **recorded packets / fake hosts**, never against the live LAN in CI.

### Alternatives Considered

- **TCA**: Excellent for scan-state machines, heavier than needed for a solo/small tool. Revisit if scan-phase UI becomes a nest of flags.
- **VIPER**: Boilerplate tax with no team-size payoff.
- **Shell out to nmap**: Fast capability, terrible notarization, auto-update, and “did we ship a GPL binary” story. Not MVP.

## Project Structure

Feature folders at the app layer; the engine is a separate Swift package so iOS can import **models + persistence + a stub engine**, not raw sockets.

```
Scanner/
├── App/
│   ├── ScannerApp.swift
│   └── Configuration/
├── Features/
│   ├── Scan/
│   │   ├── Views/
│   │   └── ViewModels/
│   ├── Inventory/
│   ├── DeviceDetail/
│   ├── Findings/
│   ├── Reports/
│   └── Settings/
├── Shared/
│   ├── Components/
│   └── DesignSystem/
├── Services/
│   ├── Persistence/          # SwiftData repositories
│   ├── Keychain/
│   ├── CVEDatabase/
│   └── FirmwareProviders/
├── Packages/
│   ├── ScanEngine/           # SPM local package
│   │   ├── Discovery/
│   │   ├── Fingerprint/
│   │   ├── Ports/
│   │   ├── Assessment/
│   │   └── Models/           # DTOs, no SwiftUI
│   └── ScanEngineMocks/
└── Tests/
    ├── ScanEngineTests/
    ├── AssessmentTests/
    └── AppTests/
```

## Layer Responsibilities

### Presentation

SwiftUI views. No sockets, no SwiftData `ModelContext` sprinkled through deep views — go through ViewModels/repositories.

### ViewModels

`@MainActor`. Hold scan progress, selection, filters. Call `ScanSession` and repositories. Map engine events → UI state.

### Scan Engine (package)

- `InterfaceService` — list interfaces, addresses, subnet
- `DiscoveryPipeline` — ARP / ICMP / TCP-ping / mDNS / SSDP
- `PortScanner` — TCP connect, optional limited UDP
- `Fingerprinter` — banners, HTTP, TLS, UPnP, SNMP
- `Assessor` — hygiene rules + CPE/CVE + firmware providers
- `ScanSession` — orchestrates phases, rate limit, cancellation (`Task` tree)

All public types are `Sendable` DTOs. Engine never imports SwiftData or SwiftUI.

### Data

SwiftData models + `InventoryRepository` that **upserts** engine DTOs (merge by MAC, then IP).

### Assessment plugins

```
protocol FindingProvider: Sendable {
    var id: String { get }
    func assess(host: FingerprintedHost, context: AssessmentContext) async -> [FindingDraft]
}
```

Built-in providers: `HygieneProvider`, `CVEMatchProvider`, `TLSProvider`, `FirmwareProvider`. New vendors = new types, not `if vendor ==`.

## Data Flow

```
User confirms scope
        ↓
ScanViewModel.start()
        ↓
ScanSession (actor)
   ├── DiscoveryPipeline  → HostDraft[]
   ├── PortScanner        → ports
   ├── Fingerprinter      → identity + evidence
   └── Assessor           → FindingDraft[]
        ↓ (AsyncStream<ScanEvent>)
ScanViewModel (progress + live table)
        ↓
InventoryRepository.upsert(run)
        ↓
SwiftData
        ↓
Inventory / Detail views
```

Cancellation: `ScanSession.cancel()` cancels the parent `Task`; probes must be `Task.checkCancellation()`-aware and close sockets in `defer`.

## Key Architectural Decisions

### 1. Unsandboxed v1, sandboxed target kept

- **Decision**: Default Debug/Release for the shipped notarized build is **not** App Sandbox. A second `Scanner-Sandboxed` scheme exists for MAS experiments.
- **Context**: ARP sweep, ICMP, and binding to network interfaces are unreliable or impossible in a default sandbox.
- **Consequences**: Direct distribution only; higher notarization bar; document exactly why.

### 2. No raw exploit surface in the engine

- **Decision**: Probe APIs are `connect`, `send` of **fixed** protocol greets (HTTP GET, SNMP GET, SSH version exchange, TLS ClientHello). No user-supplied payload field in MVP.
- **Rationale**: Removes the easy path from “assessment tool” to “attack toolkit.”
- **Consequences**: Some checks need a new typed probe to be added on purpose.

### 3. Evidence is first-class

- **Decision**: Every finding references one or more `Evidence` records (banner snippet, header, cert field, SNMP OID).
- **Rationale**: Security users will not trust a red badge.

### 4. CVE data is a local snapshot

- **Decision**: Ship a dated SQLite (or similar) CPE/CVE extract; refresh downloads a signed archive to Application Support.
- **Rationale**: NVD live API is a single point of failure and a privacy leak (querying NVD with product names from the LAN).

### 5. iOS shares models, not the engine

- **Decision**: iOS target later imports persistence + DTOs. Engine methods that need BSD sockets are `#if os(macOS)` or in the Mac-only package.
- **Rationale**: iOS companion is a viewer (plus honest, limited Bonjour).

## Concurrency

- Swift 6, approachable concurrency: UI `@MainActor`, engine `actor` + `@concurrent` for blocking socket I/O if needed.
- Cap in-flight hosts (default 32, user-tunable).
- Global token bucket for connect() rate.

## Testing Strategy

### Unit (ScanEngineTests)

- Parse fixtures: HTTP headers, UPnP XML, SSH banners, certs, NVD CVE JSON slices
- Hygiene rules against synthetic `FingerprintedHost`
- CPE version-range matching
- Inventory merge rules (MAC vs IP)

### Integration

- Loopback-only “scan 127.0.0.1” in tests with a tiny local fixture server (HTTP + banner)
- **Do not** scan the developer LAN in CI

### UI

- Authorization confirmation appears before first probe
- Cancel stops progress
- Empty / in-progress / completed scan states

**Coverage goal**: 80%+ on Assessment + merge rules; 70%+ on engine parsers. UI is secondary.

## Entitlements & TCC (Mac)

Shipped (unsandboxed) still needs:

- `NSLocalNetworkUsageDescription` — local network TCC on recent macOS
- Outbound client + inbound (mDNS/SSDP listen): conceptually `network.client` / `network.server` if we later sandbox
- Optional location **not** used
- Keychain access for credentials

Info.plist usage strings must say this is for **networks the user is authorized to assess**.

## Future

- Extract Assessment to its own package if firmware providers proliferate.
- If MAS becomes real: privileged helper is a last resort; prefer degrading discovery and labeling results incomplete.

## Related Documents

- [tech-stack.md](./tech-stack.md)
- [data-model.md](./data-model.md)
