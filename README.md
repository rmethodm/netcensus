# Netcensus

Native macOS app that inventories devices on a network you are authorized to assess, fingerprints them, and records vulnerabilities and missing updates — without exploits or brute-force.

The Xcode project remains `Scanner` (bundle `com.rmethod.Scanner`). The shipping name is **Netcensus**.

See `docs/planning/` for the product plan.

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
cd /Users/rmethodm/Macdev-local/Macosapps/Scanner
xcodegen generate
swift test --package-path Packages/ScanEngine
xcodebuild -scheme Scanner -destination 'platform=macOS' test
```

Requires Xcode 27, macOS 15+, SwiftLint (`brew install swiftlint`).

## Notarize (Developer ID)

```bash
chmod +x scripts/notarize.sh
./scripts/notarize.sh
```

Uses the Apple ID signed into Xcode (team `MNC9M36A88`). Optional for later runs:

```bash
xcrun notarytool store-credentials notarytool --team-id MNC9M36A88
```

## Live LAN dogfood

Headless scans of the attached private subnet (requires `--i-am-authorized`). Results go to `~/Library/Application Support/Scanner/dogfood/` and are not committed.

```bash
chmod +x scripts/dogfood-scan.sh scripts/install-dogfood-agent.sh
./scripts/dogfood-scan.sh
./scripts/install-dogfood-agent.sh   # daily 10:00 while this Mac is on
```

The GUI can also dogfood: Settings → Open at login, Scan when Netcensus opens, Repeat daily.
