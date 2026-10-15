# Sanitisation policy

This repo is public. My working notes are not. Everything here is rewritten from those notes, not copied, and some categories of detail are left out on purpose.

## Never published

| Category | Why |
|---|---|
| Secrets of any kind: passwords, API tokens, keys, recovery keys, webhook and health-check URLs, bot tokens | Obvious. A secret in a public commit is compromised permanently, even after deletion, because git history and forks keep it. |
| Public IP addresses, dynamic DNS names, fully qualified hostnames | They locate the network and its services on the internet. |
| The tenant's custom domain and every account address | They identify the tenant and its administrators for phishing, password spraying and consent attacks. |
| Directory and device identifiers: tenant, object, device, application and policy IDs | Useful for targeted attacks and of no value to a reader. |
| Hardware serial numbers, MAC addresses, SMBIOS UUIDs | Serials enable warranty and account-recovery fraud. MACs and UUIDs fingerprint devices. |
| Tailnet addresses, LAN addresses, non-standard service ports, admin usernames | Each one removes a step from an attacker's reconnaissance. |
| Which password manager, vault or device holds which credential | Tells an attacker where to aim. |
| Account recovery arrangements for break-glass accounts and external identities | Same reason. |
| Personal account names, purchase records, support tickets, employer details | Not relevant to the work and not mine to publish in some cases. |
| DNS filtering profile IDs | They let others use or pollute the profile. |
| DNS stamps and DoH URLs | They embed the DNS profile ID. |
| WiFi network names, the household's devices, and the ISP router's details | They identify the location and other people. |
| Purchase details, retailers and prices | Not relevant to the work. |

## Published deliberately

- **My name and LinkedIn profile.** This is a portfolio. Everything else personal stays out.
- **Internal hostnames** such as `llm01` or `mon01`. They carry no addressing or credentials.
- **Policy, group and profile display names** such as `CA001`. They explain the design.
- **Error codes, event IDs and log message text.** They are the evidence.
- **Known gaps and open faults,** described without the identifiers that would make them actionable to someone else. Hiding weaknesses would make this repo less honest, not more secure.
- **Public test endpoints** used in labs, such as Microsoft's SmartScreen test site and the ECH test site.

Screenshots follow the same rules. Addresses, MACs, serials, account names and device names are redacted before a screenshot is committed.

## How it is checked

1. Content is rewritten from notes, never pasted.
2. [`scripts/sanitise-check.sh`](scripts/sanitise-check.sh) sweeps the working tree for IP addresses, email addresses, GUIDs, MAC addresses, long hex strings and token formats, and for a private denylist of my own identifiers. The denylist file is gitignored and never committed.
3. gitleaks runs as a pre-commit hook and blocks commits containing secrets.
4. Before the repo is made public, gitleaks scans the **full history**, not only the working tree. A secret removed in a later commit is still public.
