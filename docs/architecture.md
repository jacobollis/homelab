# Architecture

## Host

| Component | Detail |
|---|---|
| Hypervisor | Proxmox VE 9.2, single node, legacy GRUB on a UEFI install |
| CPU | AMD Ryzen 9 9950X (16 cores, 32 threads) |
| Memory | 192 GB DDR5 |
| Board | ASUS ProArt X870E-Creator |
| Host console | CPU integrated graphics, so both discrete GPUs are free for passthrough |
| Uplink | Aquantia AQC113 10G, forced to 2.5G full duplex to match the switch. The onboard Intel I226-V is dead from a known firmware issue on this board family. |
| Power | CyberPower UPS, USB-attached to the host and monitored with NUT. The shutdown threshold under real load is still to be tuned. |
| Config tracking | Host configuration under etckeeper, so every change to `/etc` is a git commit |

The host is rebuilt from scratch when needed. The last rebuild was in July 2026, after two NVMe controller hangs.

The host is powered off overnight to save electricity. That decision has consequences for scheduled jobs and for the dead-man's switch. Both are covered in [monitoring and backups](monitoring-and-backups.md).

## GPU passthrough

Two GPUs are passed through with VFIO. The host never loads a driver for either.

| GPU | Slot | Assigned to | Notes |
|---|---|---|---|
| RTX 5070 Ti | PCIEX16_1, vertical mount on a 600 mm riser rated PCIe 4.0 | llm01 only | Slot capped at Gen4 in BIOS since October 2026. See [case study 1](case-studies.md#1-a-gpu-that-fell-off-the-bus-gen5-over-a-gen4-cable). |
| RTX 5080 | PCIEX16_2, direct | Shared by work01 and edit01 | Only one of the two VMs can hold it at a time |

Both x16 slots run x8/x8 with both populated.

### Sharing one GPU between two VMs

work01 and edit01 both have the RTX 5080 in their config. A Proxmox hookscript, `gpu-mutex.sh`, runs before either starts. It holds a list of VMIDs that share the card and refuses to start a VM if another VM on that list is running. It keys on VMID membership and `qm status` only. It hardcodes no PCI address, so a card can be moved between VMs by changing `hostpci` assignments without editing the script.

It only blocks starts. It performs no GPU reset, unbind or preparation.

In July 2026 I reversed the two GPUs' roles by changing `hostpci` assignments only. The cards did not move physically. The script's header comment was not updated at the time and described the old mapping for two months. The lesson is in [lessons](lessons.md).

### Settings every GPU VM on this host needs

- **CPU pinning.** A GPU VM pinned to `affinity: 0-7,16-23` with 16 cores drives a physical display. Without it, a VM can pass through the card, load the driver, set a mode and train the HDMI link, and still show nothing usable. See [case study 2](case-studies.md#2-a-gpu-vm-that-did-everything-right-and-showed-nothing).
- **`options vfio_pci disable_idle_d3=1`** host-wide. Without it, a passed-through device that drops to D3cold cannot be woken when its VM restarts, and QEMU crashes on reattach.
- **Full `qm stop` and `qm start` to apply hardware config changes.** A guest reboot keeps the old QEMU process and its old config.

### USB passthrough

work01 gets the board's ASM4242 USB4 controller as a whole PCI device, gated by the same mutex as the GPU. It also gets a single USB Bluetooth adapter by vendor and product ID. The UPS and the onboard Bluetooth module stay on the host.

Whole-controller passthrough hides every port on that controller from the host, whatever the connector shape. A device plugged into one of those ports powers up and never enumerates on the host. I map each physical port to its controller before plugging in anything that matters.

## Storage

Drives are always resolved by serial number. Device names such as `nvme0n1` change between boots on this host, and treating them as stable is how destructive commands hit the wrong drive.

| Drive | Pool | Holds |
|---|---|---|
| 4 TB NVMe | `pve` volume group, `local-lvm` | Host OS, llm01, work01, win11-ap01 |
| 4 TB NVMe | `gaming-nvme` thin pool (name kept from its first use) | mon01, tasks01, khoj01 |
| 1 TB NVMe | `edit-nvme` thin pool | edit01 |

- Thin-pool autoextend is set globally at 80 percent threshold, 20 percent growth.
- `gaming-nvme` is overcommitted on paper. vzdump warns about this on every backup. The warning is expected, and I check real usage with `lvs` rather than assuming headroom.
- One M.2 slot is empty on purpose. Populating it takes PCIe lanes from the 5070 Ti slot.
- The monitoring container sits on a different physical drive from the host OS, so a host drive failure does not take the monitoring down with it.

A separate NVMe drive in a USB enclosure is a Ventoy boot drive with checksum-verified Windows 11, Ubuntu, SystemRescue and Proxmox installers.

## Guests

### Virtual machines

| Name | OS | GPU | Role |
|---|---|---|---|
| llm01 | Ubuntu 24.04 | RTX 5070 Ti | Headless Ollama, `gpt-oss:20b` as the main model with a 32K context. Also hosts Stable Diffusion WebUI Forge, which is stopped unless needed because it competes for VRAM. |
| work01 | CachyOS, KDE Plasma 6 on Wayland | RTX 5080 (shared) | Daily work desktop, driving a TV. Obsidian synced through Syncthing. |
| edit01 | Rocky Linux 8.6 | RTX 5080 (shared) | DaVinci Resolve, NVIDIA open kernel module pinned to a known-good version |
| win11-ap01 | Windows 11 Pro 26H2 | none | Intune lab device. Registered with Autopilot, Entra joined, enrolled, compliant, BitLocker on, Defender onboarded. Disposable by design. |

### Containers (LXC)

| Name | Role |
|---|---|
| mon01 | Prometheus, Alertmanager and blackbox_exporter. Hand-installed binaries under one service account, no Docker. |
| unifi01 | UniFi Network controller for the switch and access point |
| tasks01 | Vikunja task manager |
| khoj01 | Khoj, a self-hosted search and chat over my Obsidian vault. Chat runs on llm01 over the LAN. Search embeddings run locally in the container. |

### Retired

Each retirement was a decision, not an accident. The reasons are in [decisions](decisions.md).

- Three gaming VMs. Gaming moved off this host for good.
- An n8n automation container, a Terraform container and a container-image update watcher.
- A Hetzner VPS that hosted a self-hosted chat service.
- A RHEL 10 VM used for the Intune Linux lab. The lab finished, so the VM was deleted after its Intune and Entra records were removed.

Final backup archives of destroyed guests are kept and protected from pruning.

## NAS

Synology DS1525+.

- Backup target for Proxmox, and source for the nightly offsite copy.
- Tailscale subnet router for the home LAN. It is not an exit node.
- Hub for Obsidian vault sync through Syncthing.
- Let's Encrypt certificate issued and deployed by acme.sh with a DNS challenge. The deploy step creates a throwaway admin account for each run and deletes it afterwards, so no admin password is stored in the deploy config.
