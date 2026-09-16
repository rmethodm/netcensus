# Scanner — Features

**Last Updated**: 2026-09-16

## MVP Features (v1.0 — macOS)

### 1. Authorization & Scope

- **Priority**: High
- **Complexity**: Low
- **Description**: Before any probe leaves the Mac, the user picks a network interface and confirms they are authorized to assess that subnet. Default CIDR is the interface’s IPv4 subnet. Custom CIDR is allowed only for prefixes on that interface (no arbitrary WAN ranges in MVP).
- **User Value**: Keeps the product on the right side of law and notarization.
- **Dependencies**: Interface enumeration
- **Status**: [x] Complete

### 2. Host Discovery

- **Priority**: High
- **Complexity**: High
- **Description**: Find live hosts on the scoped subnet using layered techniques, recorded per host with method and timestamp:
  - ARP table + ARP sweep (primary on Ethernet/Wi-Fi)
  - ICMP echo (when available)
  - TCP ping on a small probe set (80, 443, 22, 445, 5353)
  - mDNS / Bonjour browse
  - SSDP / UPnP M-SEARCH
  - NetBIOS name query (optional, off by default — noisy)
- **User Value**: The inventory is only as good as discovery. Security users will not trust a Bonjour-only list.
- **Dependencies**: Scope
- **Status**: [x] Complete

### 3. Device Fingerprinting

- **Priority**: High
- **Complexity**: High
- **Description**: For each live host, collect as much *identifying* data as possible without credentials:
  - IP (v4, v6 if present), MAC, OUI vendor
  - mDNS/Bonjour name and service records
  - DHCP hostname if visible
  - HTTP(S) title, Server header, well-known paths (`/`, `/login`, device XML)
  - UPnP device description (manufacturer, model, serial, presentation URL)
  - SNMP sysDescr/sysName/sysObjectID **only** if `public` answers or the user supplied a community/v3 cred
  - TLS certificate SAN, issuer, dates, protocol/cipher
  - SSH/FTP/SMTP/banner strings (first line only, truncated)
  - Open port list from a configurable TCP connect scan
- **User Value**: You cannot assess what you cannot name.
- **Dependencies**: Discovery
- **Status**: [x] Complete

### 4. Service Enumeration

- **Priority**: High
- **Complexity**: Medium
- **Description**: TCP connect scan with three profiles:
  - **Quick**: ~20 common ports
  - **Standard** (default): ~200 common ports
  - **Full**: 1–1024 + extras (slow; explicit)
  UDP is **opt-in** and limited (53, 67, 123, 161, 1900, 5353). No IP ID idle scans, no idle/zombie, no fragmentation tricks.
- **User Value**: Open services are the assessment surface.
- **Dependencies**: Discovery
- **Status**: [x] Complete

### 5. Vulnerability & Missing-Update Assessment

- **Priority**: High
- **Complexity**: High
- **Description**: Map fingerprint → CPE (or vendor/product/version) → findings. Finding types:
  - **CVE match** from local NVD/OSV snapshot (by CPE / version range)
  - **Firmware/software lag** via vendor providers (Apple software, Synology, Ubiquiti, generic “version older than known latest”)
  - **Hygiene / exposure** (not CVEs): Telnet open, SMBv1, anonymous FTP, HTTP admin with no TLS, expired/soon-expired cert, TLS1.0/1.1 only, UPnP IGD on LAN, SNMP `public` writable or world-readable, empty community, default-looking admin paths present
  - **Missing identification**: host up but no version → finding “cannot assess firmware” (informational)
- Every finding stores evidence, severity (CVSS or mapped), confidence (`high`/`medium`/`low`), and “what to do next” in human language (update, disable service, change default community — not “run this exploit”).
- **User Value**: This is the product, not the pretty map.
- **Dependencies**: Fingerprint, local CVE DB
- **Status**: [x] Complete

### 6. Optional Credentialed Checks

- **Priority**: High (audience is security professionals)
- **Complexity**: High
- **Description**: User-supplied secrets in Keychain, scoped to host or subnet, used only when attached to a scan profile:
  - SNMPv2c community / SNMPv3
  - SSH username + key or password (run a **fixed** read-only command set: OS version, package manager outdated count if available — never arbitrary remote command UI in MVP)
  - HTTP basic / cookie for device admin pages the user owns
- No brute force, no default-password lists applied automatically. A “check if this credential works” is allowed; spraying is not.
- **User Value**: Unauthenticated banners miss most missing-patch truth.
- **Dependencies**: Keychain, fingerprint
- **Status**: [x] Complete

### 7. Inventory Log & Scan History

- **Priority**: High
- **Complexity**: Medium
- **Description**: Persist devices across scans. Merge by MAC when possible, else IP+vendor heuristic. Show first-seen / last-seen, new device since last scan, gone device, changed open ports, new findings. Scan runs are immutable snapshots.
- **User Value**: Security work is “what changed,” not a one-shot list.
- **Dependencies**: Persistence
- **Status**: [x] Complete

### 8. Device Detail & Evidence

- **Priority**: High
- **Complexity**: Medium
- **Description**: One window/pane per device: identity, services, findings, raw evidence (banners, cert PEM summary, UPnP XML excerpt), notes the user types, tags, ignore-finding.
- **User Value**: Professionals need to defend a finding.
- **Dependencies**: All collection features
- **Status**: [x] Complete

### 9. Reports & Export

- **Priority**: Medium
- **Complexity**: Medium
- **Description**: Export a scan run as JSON (full), CSV (hosts + findings), and Markdown report. Copy-as-Markdown for a single host.
- **User Value**: Tickets, audits, notes.
- **Dependencies**: History
- **Status**: [x] Complete

### 10. Scan Controls

- **Priority**: High
- **Complexity**: Medium
- **Description**: Start, pause, cancel. Concurrency slider. Rate limit (packets/sec). Progress by phase (discover → fingerprint → assess). Live log (toggle, off by default).
- **User Value**: A /24 should not melt a cheap IoT cam or the Wi-Fi AP.
- **Dependencies**: Engine
- **Status**: [x] Complete

## Post-MVP (v1.1+)

### Scheduled / unattended scans

- **Target**: v1.1
- **Why later**: Needs login-item/background behavior and notification UX.
- Notify on new host or new high-severity finding.

### IPv6-first discovery

- **Target**: v1.1
- Neighbor discovery, mDNS AAAA, larger address space heuristics (don’t brute a /64).

### Extra vendor firmware providers

- **Target**: v1.1–v2.0
- More NAS, printers, cameras, consumer routers.

### iOS companion

- **Target**: after Mac v1.0
- Browse inventory, finding inbox, trigger “please scan” is **not** required. Limited on-device discovery (Bonjour + HTTP) clearly labeled incomplete.
- Sync: optional iCloud **or** file/AirDrop import of a Scanner export. Default remains local-only on Mac.

### Custom port lists & nmap XML import

- **Target**: v1.2
- Import nmap `-oX` to enrich inventory without re-scanning.

### Policy profiles

- **Target**: v2.0
- “Home lab”, “guest VLAN”, “no telnet anywhere” as saved baselines.

## Explicitly Out of Scope (all versions unless product direction changes)

- Exploit execution, PoCs, shellcode, Metasploit-style modules
- Password spraying, credential stuffing, default-password dictionaries applied to hosts
- Attacking hosts on the public Internet / arbitrary WAN CIDRs as a first-class flow
- Packet injection, MITM, ARP spoofing, rogue DHCP
- Hidden scanning (no decoys, no idle scan)
- Bundling nmap/masscan binaries unless we later decide to shell out with user consent (not MVP)

## Feature Dependencies

```
Authorization & Scope
├── Host Discovery
│   ├── Fingerprinting
│   │   ├── Service Enumeration
│   │   ├── CVE / firmware assessment
│   │   └── Credentialed checks (optional)
│   └── Inventory merge
├── Device Detail
├── History / diffs
└── Export
```

## Feature Estimates

| Feature | Complexity | Effort | Priority |
|---------|-----------|--------|----------|
| Scope + authorization | Low | 2–3 days | High |
| Host discovery | High | 2 weeks | High |
| Fingerprinting | High | 2 weeks | High |
| Service enumeration | Medium | 1 week | High |
| CVE DB + matching | High | 1.5 weeks | High |
| Hygiene checks | Medium | 1 week | High |
| Credentialed checks | High | 1.5 weeks | High |
| SwiftData inventory/history | Medium | 1 week | High |
| Device UI + evidence | Medium | 1.5 weeks | High |
| Export | Medium | 3–4 days | Medium |
| Scan controls / rate limit | Medium | 4–5 days | High |
| Notarization + hardening | Medium | 1 week | High |

MVP is intentionally large. If it must slip, **cut credentialed SSH first**, keep SNMP + hygiene + CVE.

## Related Documents

- [overview.md](./overview.md)
- [roadmap.md](./roadmap.md)
