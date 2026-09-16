# Netcensus

Native macOS app that inventories devices on a network you are authorized to assess, fingerprints them, and records vulnerabilities and missing updates — without exploits or brute-force.

The Xcode project remains `Scanner` (bundle `com.rmethod.Scanner`). The shipping name is **Netcensus**.

See `docs/planning/` for the product plan. Clone the local repo and `git push` after `gh auth login` to publish the full source; this GitHub copy currently holds the download landing files.

## Download

Developer ID signed and notarized builds: [GitHub Releases](https://github.com/rmethodm/netcensus/releases).

macOS 15 or later. Unzip and drag **Netcensus.app** to Applications. The first scan asks you to confirm you are authorized to assess that subnet.

## Current (v1.0)

- Live discovery, fingerprinting, and assessment
- Export JSON/CSV/Markdown; inventory new/gone/changed
- Acknowledge / ignore findings; hide ignored in the inbox
- Scheduled scans while the app is open; optional Open at login
- Keychain-backed SNMPv2c, SSH keys, and HTTP basic (one stored login, no spraying)
- Optional scan when the app opens (pairs with Open at login)
- Retention prune; quieter unidentified findings

## Build

```bash
xcodegen generate
swift test --package-path Packages/ScanEngine
xcodebuild -scheme Scanner -destination 'platform=macOS' test
```

Requires Xcode 27, macOS 15+, SwiftLint (`brew install swiftlint`).
