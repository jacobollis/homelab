# Monitoring and backups

## Monitoring design

The monitoring stack lives in mon01, a container on a different physical drive from the host OS. If the host's main drive fails, the thing that should tell me about it keeps running long enough to do so.

| Component | Role |
|---|---|
| Prometheus | Scrapes the host, the Proxmox API, the NAS, llm01 and the GPU exporter |
| Alertmanager | Routes alerts to a Telegram bot |
| blackbox_exporter | HTTP probes against application endpoints |
| Healthchecks.io | Two external dead-man's switches |

All binaries are installed by hand under one service account, with their own systemd units. No distribution package and no Docker. Prometheus reloads with SIGHUP through a systemd drop-in. Alertmanager has no reload action in its unit, so it is reloaded with `systemctl kill -s HUP` and the journal is checked for a successful config load.

### Rule groups

Availability, storage, SMART, thermal, power, Ollama, application probes, NAS backup space, backup coverage, certificates, NVMe bus drops and NVMe kernel errors, plus a proof-and-watchdog group.

### Drive-fault detection

The host had two NVMe controller hangs in mid 2026. Three detectors now cover that failure, each independent of the others:

- `NvmeControllerFault` for a controller fault on a drive that is still present.
- `NvmeDriveVanished` for a drive that has dropped off the bus.
- `HostNodeExporterDown` for a host that has stopped reporting at all, which is what a hang on the OS drive looks like from outside.

The packaged SMART collector timer only starts when SATA disks exist. On an NVMe-only host it never fired. A systemd drop-in adds an NVMe path condition to the timer.

### Application probes

blackbox_exporter probes the task manager, Khoj and Ollama over HTTP. Each has a rule that fires after three minutes of failure. The alert path was tested end to end.

### Dead-man's switches

- Alertmanager pings a Healthchecks.io check every minute through a dedicated watchdog route. If the monitoring stack dies, the pings stop and Healthchecks alerts.
- The NAS runs a scheduled task every minute that requests the Proxmox web UI and pings a second check. It tests the real service, not ICMP.

Healthchecks checks are rotated without a gap: create the new check, repoint the config, confirm it goes green, then delete the old one.

### Backup coverage check

A script on the host compares running containers with the members of the nightly backup pool. It writes the gap as metrics to node_exporter's textfile collector every 15 minutes. An alert fires if any running container is outside the pool. I tested it with a throwaway container.

### Known monitoring gaps

Listed so they are not mistaken for coverage:

- **llm01 up but its GPU gone.** In October 2026 the 5070 Ti fell off the bus at boot. llm01 kept running and every probe stayed green, because the Ollama probe checks an HTTP endpoint and the exporter rule checks that the exporter answers. A rule for this is the next monitoring job.
- **Certificate expiry.** A certificates rule group exists, but it did not fire before the NAS certificate expired in September 2026. Not yet explained.
- **Planned downtime.** The host powers off overnight, and the NAS dead-man's switch cannot tell that from an outage. Muting it would trade a false positive for a blind spot. An expected-downtime design is still to do.
- **Mail flow.** Nothing alerts if the tenant domain stops receiving mail.

## Backups

| Job | Schedule | Scope | Retention |
|---|---|---|---|
| nightly-lxc | 01:00 | Every container in the `nightly-lxc` pool | 7 daily, 4 weekly |
| work01 | 01:30 | work01 | 2 daily, 1 weekly |
| weekly-llm01 | Sunday 00:00 | llm01, about 130 GB per archive | 2 weekly |
| Offsite | 02:00 | NAS Hyper Backup to a Hetzner Storage Box | Nightly incrementals |

Design points:

- **Scope by pool membership, not a list of IDs.** Adding a container to the pool is the single act that brings it into scope. Enumerated lists go stale the day a new guest is built. The coverage check above enforces this.
- **`repeat-missed 1` on every job.** With the host off overnight, a clock-scheduled backup would simply never run. A missed run now fires once soon after the next boot. Verified after an overnight power-off.
- **zstd compression** on every job. All jobs finish before the 02:00 offsite run.
- **Container backups use a local tmpdir.** In stop mode to the NAS share, tar runs as the container's mapped UID and cannot write its temp file there.
- **The Autopilot lab VM has no backup, by design.** The value of those labs lives in tenant-side objects. Rollback points are Proxmox snapshots taken per lab.
- **Khoj's database is backed up crash-consistent,** since Postgres runs live in Docker. Acceptable in snapshot mode. A clean dump would need a pre-backup hook.

Two behaviours worth knowing:

- Proxmox retention never prunes archives for a VMID no job backs up any more. That covers destroyed guests and repointed jobs. I protect the final archive I want and free the rest by hand.
- A backup of a stopped VM starts its QEMU process paused, which opens and resets its passed-through devices. A running VM's backup does not touch them.
