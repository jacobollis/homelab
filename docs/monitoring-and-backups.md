# Monitoring and backups

## Monitoring design

The monitoring stack lives in mon01, a container on a different physical drive from the host OS. If the host's main drive fails, the thing that should tell me about it keeps running long enough to do so.

| Component | Role |
|---|---|
| Prometheus | Scrapes the host, the Proxmox API, the NAS, llm01, the GPU exporter and the UPS exporter |
| Alertmanager | Routes alerts to a Telegram bot |
| blackbox_exporter | HTTP, TLS and ICMP probes |
| Healthchecks.io | Two external dead-man's switches |

All binaries are installed by hand under one service account, with their own systemd units. No distribution package and no Docker. Prometheus reloads with SIGHUP through a systemd drop-in. Alertmanager has no reload action in its unit, so it is reloaded with `systemctl kill -s HUP` and the journal is checked for a successful config load.

36 rules in 14 groups: proof-and-watchdog, availability, storage, SMART, thermal, power, Ollama, application probes, NAS backup space, backup coverage, certificates, NVMe bus drops, NVMe kernel errors and gateway.

Every new alert is proved before I rely on it: invert or redirect the condition, watch it fire and resolve on Telegram, then set it back in the same sitting and grep the rule file.

### Drive-fault detection

The host had two NVMe controller hangs in mid 2026. Three detectors now cover that failure, each independent of the others:

- `NvmeControllerFault` for a controller fault on a drive that is still present.
- `NvmeDriveVanished` for a drive that has dropped off the bus.
- `HostNodeExporterDown` for a host that has stopped reporting at all, which is what a hang on the OS drive looks like from outside.

The packaged SMART collector timer only starts when SATA disks exist. On an NVMe-only host it never fired. A systemd drop-in adds an NVMe path condition to the timer.

### GPU-absent alert

In October 2026 the RTX 5070 Ti fell off the bus at boot. llm01 kept running and every probe stayed green, because the Ollama probe checks an HTTP endpoint and the exporter rule checks that the exporter answers.

`Llm01GpuAbsent` now fires when the GPU exporter is up but reports no card, or when `nvidia-smi` itself fails:

```promql
(absent(nvidia_smi_gpu_info{job="llm01-gpu"}) and on() up{job="llm01-gpu"} == 1)
  or nvidia_smi_command_exit_code{job="llm01-gpu"} != 0
```

Proved by pointing `absent()` at a series name that does not exist. Firing and resolved both reached Telegram.

### Certificates

- `CertExpiringSoon` warns when any probed certificate has under 21 days left.
- `CertProbeFailing` warns when a certificate probe cannot read its certificate for 30 minutes. A failing TLS probe never produces the expiry metric, so without this rule an expiry alert goes silent exactly when it is needed. See [case study 10](case-studies.md#10-two-certificate-probes-that-could-not-fail-loudly).
- Probes cover the Proxmox UI and the NAS.

### Gateway

A blackbox ICMP probe pings the gateway, and `GatewayDown` fires after two minutes. The probe needed `CAP_NET_RAW`: blackbox runs as an unprivileged user in an unprivileged container whose ping group range excludes it. A systemd drop-in grants the capability to that one service, rather than widening the container's sysctl.

A dead gateway also cuts mon01's way to Telegram, so that alert only arrives once the gateway is back. The external Healthchecks watchdog is the out-of-band signal for that case.

### UPS

NUT's exporter feeds three rules: on battery, low battery (which now means the host shutdown is starting), and runtime under 25 minutes, five minutes before the shutdown threshold. The runtime rule used to fire below 5 minutes, after the host would already have been shutting down.

Alertmanager's warning route waits 30 seconds before its first send. With a 30-second `for` on the rule, an outage shorter than about 75 seconds never notifies, because it resolves first. A 55-second test pull did exactly that. That is the intended floor, and it is written down so a short test is not mistaken for a broken path.

### Application probes

blackbox_exporter probes the task manager, Khoj, Open WebUI and Ollama over HTTP. Each has a rule that fires after three minutes of failure. The alert path was tested end to end.

### Dead-man's switches

- Alertmanager pings a Healthchecks.io check every minute through a dedicated watchdog route. If the monitoring stack dies, the pings stop and Healthchecks alerts.
- The NAS runs a scheduled task every minute that requests the Proxmox web UI and pings a second check. It tests the real service, not ICMP.

Healthchecks checks are rotated without a gap: create the new check, repoint the config, confirm it goes green, then delete the old one.

### Backup coverage check

A script on the host compares running containers with the members of the nightly backup pool. It writes the gap as metrics to node_exporter's textfile collector every 15 minutes. An alert fires if any running container is outside the pool. I tested it with a throwaway container.

### A false alert worth knowing about

During the renumber, `Llm01Down` fired while llm01 was running. The Proxmox exporter reads guest state from the cluster resources API, which `pvestatd` feeds. Restarting the cluster service without restarting `pvestatd` left every guest reported as unknown, so every guest read as down. Restarting `pvestatd` fixed it.

### Known monitoring gaps

Listed so they are not mistaken for coverage:

- **Planned downtime.** The host powers off overnight, and the NAS dead-man's switch cannot tell that from an outage. Muting it would trade a false positive for a blind spot. An expected-downtime design is still to do.
- **Mail flow.** Nothing alerts if the tenant domain stops receiving mail.
- **One dead scrape job.** A SMART exporter job points at an exporter that was never built. It reads down permanently, which hides any new down target in a quick count. SMART data still arrives through the node_exporter textfile collector. To be built or deleted.
- **No syslog receiver yet** for the gateway's firewall and IPS logs.

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
- **The NFS export is scoped to the host's address.** The renumber sweep found that moving the host without a new export rule would have broken every backup. A manual backup over the new export was one of the renumber's verify gates.
- **The Autopilot lab VM has no backup, by design.** The value of those labs lives in tenant-side objects. Rollback points are Proxmox snapshots taken per lab, and deleted once the lab is banked.
- **Khoj's database is backed up crash-consistent,** since Postgres runs live in Docker. Acceptable in snapshot mode. A clean dump would need a pre-backup hook.

Two behaviours worth knowing:

- Proxmox retention never prunes archives for a VMID no job backs up any more. That covers destroyed guests and repointed jobs. I protect the final archive I want and free the rest by hand.
- A backup of a stopped VM starts its QEMU process paused, which opens and resets its passed-through devices. A running VM's backup does not touch them.
