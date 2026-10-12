# Lessons

Operating principles from running this estate. Each one cost me time before I wrote it down.

## Method

- **Ground truth first.** Pull live state before acting. Documented state can be wrong, not only stale. My own notes recorded a working VM's passthrough as unverified, and a riser as the wrong length.
- **Resolve drives by serial and PCI devices with `lspci`.** Device names reshuffle between boots.
- **When two systems differ and one works, test the working one.** Vary the thing you have not varied yet.
- **A test that cannot fail proves nothing.** A clean result means little unless the old state is known to fail under the same conditions.
- **A failing test rig proves nothing until a known-good part passes it.** The twin of the rule above.
- **Change one variable at a time,** even when a second suspect is in the same settings screen.
- **A diagnosis is only as sound as the platform it was taken on.** Confirm the machine underneath is healthy before blaming the software on top.
- **Read the tool's own report before forming theories.** Intune's Linux agent logged expected and actual values for every setting. I made three changes before reading it.
- **Record hardware by part number from the order, not from memory.**
- **Convert time zones before correlating logs.** A guest logging UTC and a host logging BST put an effect before its cause.
- **Save incident logs somewhere other than the failing device, and record where.**

## Monitoring

- **Monitoring must not share a failure domain with what it monitors.**
- **Probe the dependency, not only the service.** A GPU fell off the bus and every probe stayed green, because the HTTP endpoint still answered.
- **Test a false-positive theory against the data before tuning an alert.** Doing so exposed a five-week outage.
- **A task that reports Success has proved only that it exited cleanly.** Verify the outcome.
- **A Prometheus `for` timer restarts at every reload.** Expect a fresh wait when testing a new rule.
- **A systemd timer's `Condition*=` gates only the timer.** Starting the service by hand bypasses it, so a manual run proves nothing about the schedule.
- **An Alertmanager silence is temporary.** Anything meant to stay off is commented out at the rule with a dated note on what re-arms it.
- **End every monitoring session with a dashboard check.** A real red alert once hid among test alerts for six days.
- **Zero AER counters can mean AER is not collected at all.** Check the root port advertises the capability before trusting a zero.

## Change safety

- **`sed` exits silently when nothing matches.** Grep the file after every edit.
- **`pvesh set` prints nothing on success.** Follow it with a `pvesh get`.
- **A VM's hardware config applies only on a full stop and start.** A guest reboot keeps the old QEMU process.
- **Package removal scripts stop services by unit name,** whatever binary the unit actually runs. Check service status after any package operation.
- **`purge` deletes modified config files without asking.** Back them up first.
- **Read the `apt autoremove` list before confirming it.**
- **Before decommissioning a host, check what calls into it,** not only what runs on it.
- **Delete a server's DNS records before deleting the server,** or the next holder of that IP inherits your name.
- **Run multi-line command blocks one command at a time** when a session crosses hosts. Buffered input can land on the wrong machine.
- **Never paste command output back into a shell.** Any line that is a valid command will run.
- **Compose stacks need an explicit restart policy.** Without one, a reboot leaves containers down.
- **Update a script's header comments in the same edit as its logic.** A wrong comment inside the file that enforces a rule is worse than none.

## Secrets

- **A secret is compromised the moment it is pasted into a chat or ticket.** Deleting the transcript reduces exposure. Rotation is the remedy.
- **Write secrets directly into the file on the target host and verify structurally:** line count, hash comparison, a redacted print. Never echo the value back.
- **Placeholder discipline and secret discipline are the same habit.** Literal placeholder text in live config and a pasted real value both come from copying a code block wholesale instead of editing on the host.
- **A secret scanner on the repo does not cover the channel the repo was built in.** The commit hook blocks secrets in git. Nothing blocks a paste.
- **A redaction filter must match the file's syntax.** A `key=value` filter does nothing to YAML.
- **The SHA-256 of empty input starts `e3b0c44298fc`.** If two "secrets" hash to that, the grep matched nothing.

## Virtualisation and hardware

- **A passive riser caps the link at its own rating, and Auto does not know it.** Set the slot's link speed in BIOS to the cable's rating.
- **An idle PCIe link reading is not evidence of degradation.** NVIDIA cards drop to Gen1 at idle. Measure under load.
- **Map slots to root ports with `dmidecode -t 9` before changing a per-slot BIOS setting.**
- **`qm showcmd --pretty` shows what QEMU is actually told.** `qm config` is the abstraction.
- **A model must fit fully in VRAM with its context to be usable for interactive work.** Benchmarks of models that spill to system RAM do not transfer.
- **Keep Ollama's local settings in a systemd drop-in.** The installer rewrites the main unit on every upgrade.
- **On CachyOS, prefer AUR source packages over `-bin` packages** for anything linking system libraries.

## Networking

- **Change a guest's LAN IP over its tailnet address.** The SSH session survives the renumbering.
- **Tailscale ping bypasses ACL grants.**
- **A guest firewall rule does not open a port on the tailnet.** Check the grant.
- **Tagging a Tailscale device removes its member status.** Check what it currently gets as a member before tagging it.
- **Windows Firewall's `LocalSubnet` scope means the physical NIC's subnet,** not an overlay network. Scoping RDP to it to mean "Tailscale only" locked me out of a VPS.
- **An active exit node is a silent DNS variable.**
- **Recreate every DNS record before switching nameservers.**

## Microsoft 365, Intune and Entra

- **"Compliant" means something only if a policy was evaluated.** Set the no-policy default to Not compliant before building compliance-based Conditional Access.
- **Read the per-setting view, not the badge.** Policy delivery and compliance evaluation are separate steps, and the device header updates last.
- **Error and Noncompliant are different results.** Error means the device could not evaluate the setting. Fix the reporting, never by removing the setting.
- **Intune status lags the device.** Read the registry or the app's own policy page first.
- **Succeeded means the setting was accepted, not that the device matches it.**
- **A Conditional Access policy with no target resources evaluates nothing** and looks healthy in the portal.
- **An unassigned profile also looks healthy.** Check assignments first when a profile seems to do nothing.
- **Report-only results are on their own tab** in a sign-in's details, not in the list view's Conditional Access column.
- **Break-glass accounts need a registered MFA method** whatever the Conditional Access exclusions say.
- **Consent and token issuance are separate.** Conditional Access can refuse the token. It cannot stop a Global Administrator consenting for the whole organisation.
- **Global Administrator does not include eDiscovery.**
- **Autopilot name templates support `%SERIAL%` and `%RAND:x%` only,** 15 characters. Apple and Android profiles use a different syntax that looks similar enough to copy by mistake.
- **An Autopilot hardware hash comes from the SMBIOS serial.** Set it before first boot.
- **Each Shift+F10 session at OOBE starts from scratch.** Execution policy and loaded modules do not carry over.
- **A Windows console in QuickEdit selection pauses the process writing to it.** Check for `Select` in the title bar before calling a job hung.
- **Never deploy one app through both LOB and Win32 channels.**
- **The Apple MDM push certificate is renewed, never recreated.**
- **Editing an iOS app protection policy can reset its device-type targeting.** Scope with an assignment filter.
- **Firefox on macOS never presents a device identity to Conditional Access.**
- **Read admin-only state on a standard-user device with a SYSTEM platform script** that writes to a public folder. Never write secrets to it.
- **Check SharePoint and OneDrive sharing defaults on any tenant you touch.**
- **Quote the customer-managed Compliance Manager score,** not the overall figure.
