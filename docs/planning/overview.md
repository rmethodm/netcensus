# Scanner — Overview

**Last Updated**: 2026-09-16
**Working title**: Scanner (Xcode project / workspace name, bundle `com.rmethod.Scanner`)
**Shipping name**: Netcensus

## Quick Summary

- **Purpose**: Inventory every host on a network you control, identify it as completely as possible, and report vulnerabilities and missing software/firmware — without attacking anything.
- **Target Users**: Security professionals, homelab operators, and IT admins who own or are authorized to assess the LAN.
- **Platform**: macOS 15+ native (MVP). iOS companion later (view history / limited discovery).
- **Project Type**: Personal / professional tool, built to ship.
- **Status**: v1.0 (macOS, Developer ID + notarization)
- **Distribution**: GitHub Releases (`rmethodm/netcensus`). Not Mac App Store in v1.

## Vision

Most LAN “scanners” on Apple platforms stop at a pretty device list. Security people still drop to nmap, Nessus, or a pile of scripts. Scanner is a native Mac app that does the whole defensive loop in one place: discover, fingerprint, assess, log, and compare over time.

The product promise is **authorized assessment, not offense**. Findings are evidence (open service, banner, CPE, CVE, firmware lag). The app never includes exploits, brute-force, or attack payloads.

## Decisions Already Made

| Topic | Decision |
|-------|----------|
| Platform | macOS first; iOS later |
| Audience | Security professional |
| Scan depth | Maximum identification that is legal/ethical on networks you control |
| Distribution | Notarized direct download |
| Docs | `docs/planning/` |

## Key Decisions

### Architecture

- **Pattern**: MVVM + a protocol-based **Scan Engine** of actors
- **Rationale**: SwiftUI-native UI, highly testable discovery/assessment pipelines, concurrent host work without putting sockets on the main actor.

### Tech Stack

- **UI**: SwiftUI (macOS), AppKit only where Network/Interface APIs require it
- **Min macOS**: 15
- **Persistence**: SwiftData (inventory, scan runs, findings) + Keychain (optional credentials)
- **Backend**: None required. CVE/CPE feeds downloaded as signed snapshots, cached on disk.
- **Networking**: Network.framework + BSD sockets in the scan engine (not URLSession-only)

### Timeline

- **MVP**: ~8–10 weeks for a usable Mac tool (discover → fingerprint → assess → history)
- **v1.0**: After polish, notarization, privacy policy, and a real LAN test matrix
- **iOS companion**: After Mac v1.0 is stable

## Hard Product Rules

These are product constraints, not slogans:

1. **Authorization gate.** First scan on a new interface/subnet requires an explicit “I am authorized to assess this network” confirmation. Default scope is the current interface’s RFC1918 (or ULA) subnet.
2. **Local by default.** No cloud account. Scan results stay on device. Optional iCloud later for the iOS viewer, off by default.
3. **Identify, don’t exploit.** No exploit modules, no PoCs, no credential stuffing, no password spraying, no packet-injection attacks.
4. **Degrade honestly.** If a check cannot run (permissions, host down, no banner), record `unknown` — never invent a CVE.
5. **iOS is a companion, not a clone.** iOS cannot match Mac scan depth. Do not pretend it can.

## Competitive Position

| Product | What they do | Gap Scanner fills |
|---------|--------------|-------------------|
| Fing | Consumer LAN map | Shallow on CVE/firmware; cloud-leaning |
| Angry IP / LanScan | Fast host list | Little assessment |
| nmap / Zenmap | Gold-standard discovery | Not native Mac UX; no inventory history |
| Nessus / OpenVAS | Real vuln management | Heavy, licensed, overkill for a LAN sitting on a Mac |
| Little Snitch / Lulu | Egress control | Different job |

**Differentiation**: Native Swift Mac app, local-first inventory with history, CPE/CVE matching, firmware-age providers, security-pro reporting, no exploit pack.

## Key Risks & Mitigation

1. **Capability vs sandbox** — ARP, ICMP, and some probes fail in a tight App Sandbox. **Mitigation**: v1 is unsandboxed, notarized; keep a sandboxed build target so MAS is not a rewrite later.
2. **App Review / notarization wording** — “vulnerability scanner” triggers extra scrutiny. **Mitigation**: Market as authorized network inventory + risk assessment; document the no-exploit policy in the app and privacy policy.
3. **False positives** — Banner-based CVE matching is noisy. **Mitigation**: Confidence scores, evidence payload on every finding, never auto-mark “exploitable.”
4. **Legal misuse** — A capable scanner can be pointed at networks the user does not own. **Mitigation**: Scope lock to attached interfaces, confirmation copy, audit log of scan targets, no “scan any IP range” as the default UI.
5. **CVE feed quality / rate limits** — NVD API is flaky. **Mitigation**: Vendor a periodic CPE/CVE snapshot (NVD + optional OSV), ship with a dated DB, refresh in-app.
6. **Firmware coverage** — No single feed covers every IoT vendor. **Mitigation**: Provider plugins (Apple, Ubiquiti, Synology, generic HTTP/UPnP version) with an explicit “no feed for this vendor” state.

## Success Metrics

- A typical home/lab /24 is inventoried in under 60 seconds for discovery, under 5 minutes for a full service+assessment pass.
- ≥90% of responsive hosts get a hostname or vendor, not just an IP.
- Every finding shows evidence (port, banner snippet, CPE, CVE id) and a confidence level.
- Crash-free on the developer’s daily LAN for two weeks before v1.0.
- Zero exploit-shaped code in the repo (fitness function / review checklist).

## Related Documents

- [features.md](./features.md) — Feature list and roadmap
- [architecture.md](./architecture.md) — Architecture
- [tech-stack.md](./tech-stack.md) — Technology choices
- [ui-ux.md](./ui-ux.md) — Design and UX
- [data-model.md](./data-model.md) — Entities
- [personas.md](./personas.md) — Users
- [roadmap.md](./roadmap.md) — Timeline
