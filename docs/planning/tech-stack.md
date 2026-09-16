# Scanner — Tech Stack

**Last Updated**: 2026-09-15

## UI Framework

**Choice**: SwiftUI on macOS, AppKit bridges only for interface/routing tables if Network.framework is insufficient.

### Rationale

New app, professional three-pane inspector UI is natural in SwiftUI (`NavigationSplitView`).

### Version Support

- **Minimum macOS**: 15
- **Target**: macOS 26 (Tahoe) APIs used when they simplify Observation / networking; gated if needed
- **iOS companion (later)**: iOS 18+
- **Rationale**: Personal/pro tool; no need to support old OS. Observation + SwiftData + modern Network APIs matter.

## Persistence

**Choice**: SwiftData for inventory, scan runs, findings, evidence.

**Keychain** (Security framework) for SNMP/SSH/HTTP secrets. Never SwiftData for passwords.

**File system**: CVE snapshot SQLite (or GRDB) in Application Support; report exports via NSSavePanel.

### Data Sync

- **Strategy**: None in v1
- **iOS later**: Optional iCloud **or** file import; default off

## Networking / Scanning

| Need | API |
|------|-----|
| Interface list, path | `NWInterface`, `NWPathMonitor`, `getifaddrs` |
| TCP connect + timeout | `NWConnection` and/or non-blocking BSD sockets |
| HTTP fingerprint | `URLSession` with custom timeout, **no** shared cookie jar across hosts |
| TLS metadata | `sec_protocol_metadata` / `URLSession` delegate + `SecTrust` |
| mDNS | `NWBrowser` / `NetServiceBrowser` |
| SSDP | UDP multicast 239.255.255.250:1900 |
| ICMP / ARP | BSD sockets; fail soft if denied |
| SNMP | Minimal built-in BER GET (v2c); do not take a huge SNMP stack unless needed |

**Not used in MVP**: Alamofire, nmap binary, libpcap (adds signing/extension pain). Revisit libpcap only if passive-only mode is a real product need.

## CVE / firmware intelligence

- Periodic extract of NVD CVE + CPE (and/or OSV) built offline, shipped as a versioned snapshot
- Refresh: HTTPS download of our hosted or user-provided snapshot; verify checksum
- Firmware: `FirmwareProvider` types with vendor-specific latest-version tables (bundled JSON, updated with the app and via snapshot)

## Dependency Management

**Choice**: Swift Package Manager only.

### Third-Party Dependencies

| Dependency | Purpose | Justification |
|-----------|---------|---------------|
| SwiftLint | Linting | Quality; no runtime |
| (optional) GRDB | CVE SQLite if SwiftData is a poor fit for 100k+ CVE rows | Decision at implementation time — CVE DB is read-heavy and large |

**Default: zero runtime dependencies.** Add GRDB only if SwiftData cannot query the CVE set in <50ms per host.

Do **not** add: Alamofire, Realm, Firebase, Sparkle until we have an update story (Sparkle is likely v1.1 for direct distribution).

## Development Tools

- **Linting**: SwiftLint
- **Formatting**: SwiftFormat optional
- **Crash reporting**: none in v1 (local tool; add later if distributed widely)
- **Analytics**: none (privacy; security audience will punish telemetry)

## Backend Services

**Choice**: None for app function.

Optional later: static HTTPS for CVE snapshot hosting (GitHub Releases is enough).

## CI/CD

**Choice**: GitHub Actions (or local scripts) running `swift test` on the ScanEngine package + `xcodebuild test` when a Mac runner exists.

Notarization is a release script (`notarytool`), not CI-critical for MVP.

## Sandbox / signing

| Build | Sandbox | Use |
|-------|---------|-----|
| `Scanner` (ship) | Off | Notarized Developer ID |
| `Scanner-Sandboxed` | On + network client/server | Future MAS / capability tests |

Hardened Runtime **on** for notarization. Disable library validation only if we never load plugins; prefer in-process Swift providers.

## Tech Stack Summary

```
UI:           SwiftUI
macOS:        15+
Architecture: MVVM + actor ScanEngine
Persistence:  SwiftData + Keychain + CVE SQLite snapshot
Backend:      None
Networking:   Network.framework + BSD sockets
Dependencies: SPM, ideally none at runtime
CI/CD:        GitHub Actions / xcodebuild
Distribution: Developer ID + notarytool
Updates:      Manual in v1; Sparkle candidate for v1.1
```

## Alternatives Considered

### Bundle nmap

- **Pros**: Instant capability
- **Cons**: GPL, extra binary notarization, “why is nmap in this app,” harder to reason about probes
- **Why not**: Rebuild the subset we need; import nmap XML later

### Mac App Store first

- **Pros**: Distribution
- **Cons**: Sandbox kills the product promise
- **Why not**: User chose direct download

## Related Documents

- [architecture.md](./architecture.md)
- [overview.md](./overview.md)
