# Netcensus Privacy Policy

**Last updated**: 2026-09-16

Netcensus is a local network assessment tool. Scan results stay on this Mac unless you export them.

## Data Netcensus collects

- Network interface names, IP addresses, MAC addresses, hostnames, service banners, and similar technical identifiers on networks you confirm you are authorized to assess
- Optional SNMP communities and SSH key paths you store for authenticated checks (secrets in Keychain)
- Scan history in the app’s local SwiftData store

Netcensus does not create an account and does not send telemetry, analytics, or crash reports.

## Data Netcensus does not collect

- Contacts, photos, location traces, or files outside what you choose to export
- Traffic contents beyond the banners and protocol metadata needed to identify a service
- Passwords except those you explicitly save for credentialed checks

## Sharing

There is no backend. Nothing is uploaded. You may export JSON, CSV, or Markdown reports and share those files yourself.

## CVE and firmware catalogs

Vulnerability and firmware catalogs ship as local snapshot files inside the app. Product names from your LAN are matched on-device. They are not queried out to NVD or other cloud APIs in this version.

## Your choices

- Delete scan history by removing the app (and its container) or clearing its data
- Decline Local Network permission; discovery will be incomplete
- Export and delete files you create

## Contact

This is a directly distributed tool. Questions go to [github.com/rmethodm/netcensus/issues](https://github.com/rmethodm/netcensus/issues).
