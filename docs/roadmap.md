# Roadmap

Open faults, known gaps and next work, as of 12 October 2026. Listed in priority order within each group.

## Open faults

- **RTX 5070 Ti link stability.** Slot capped at Gen4. Closes after seven consecutive clean cold boots. If a load fault recurs at Gen4, the riser gets replaced. See [case study 1](case-studies.md#1-a-gpu-that-fell-off-the-bus-gen5-over-a-gen4-cable).
- **Then: move the firmware's primary display to the integrated GPU,** so firmware stops initialising a card that VFIO later takes. Held back until the link test closes.
- **Wake-on-LAN from power-off fails.** The likely cause is the uplink NIC's forced link speed being lost on standby power. Diagnosis planned for the next shutdown.
- **Host and llm01 package updates** are held until the GPU test closes, so a kernel change does not muddy the result.

## Monitoring gaps

1. Alert when llm01 is up but its GPU is missing. Next job.
2. Find out why the certificate expiry rule did not fire, and add a probe that warns 14 days ahead.
3. A DNS probe on the tenant domain's MX record, so a deleted record alerts.
4. An expected-downtime design for the dead-man's switch.
5. Rebuild the out-of-band kernel log path (netconsole) on the working NIC. It died with the old one.
6. Broader exporter coverage and a per-port switch link-down alert.

## Security hardening

- Move tenant administration to a dedicated cloud-only admin account, then remove Global Administrator from my daily account.
- Windows LAPS through Intune for the lab device, which currently has no local admin route by design.
- DMARC from `p=none` to quarantine, after fixing Proxmox's unaligned notification mail.
- A dedicated least-privilege NAS account for the work desktop's file share mount.
- Per-host DNS API tokens for certificate renewal instead of one shared token.
- A dedicated Tailscale tag for the subnet router, so route auto-approval applies to it alone.
- Test, then fix or delete, the SSH rule to the exit nodes.
- Review whether the NAS's SFTP service is needed, and disable it if not.

## Lab work

- Finish Remediations: the scheduled run and the portal device status.
- Retention label: apply it once it propagates.
- Sensitivity label: open the protected file in Word desktop as an outside identity to evidence the refusal.
- Research whether a standard user's one-click override of a threat-intelligence block can be prevented. Record nothing until it is verified.
- Lab device teardown in the correct order once all evidence is banked.

## Infrastructure

- A real cable run plus my own router with the ISP router in modem mode. Removes the 100 Mbps WAN cap and unblocks VLAN segmentation.
- Decide whether the work desktop moves into the static address band.

## Repo

- Publish the Terraform files from the retired infrastructure-as-code container, after a gitleaks pass, so that work has inspectable evidence.
- Architecture diagrams for networking and backups.
