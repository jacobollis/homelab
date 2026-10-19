# Decisions

Short records of design decisions: what was chosen, what it rules out, and why.

## Monitoring lives on a different drive from the host OS

The monitoring container sits on a separate NVMe pool. The host had two controller hangs on one drive. Monitoring that shares a failure domain with what it monitors goes quiet at the moment it matters.

## Backup scope is pool membership, not a list of IDs

A list of VMIDs goes stale the day a guest is added. Pool membership makes one act, adding the container to the pool, bring it into scope. An automated check alerts if a running container is outside the pool, so the rule is enforced rather than documented.

## Backups catch up after downtime instead of assuming the host is up

The host powers off overnight. Every backup job carries `repeat-missed 1`, so a missed run fires once after the next boot. A boot-triggered script was planned first and proved unnecessary.

## The dead-man's switch stays loud during planned downtime

The NAS dead-man's switch cannot yet tell overnight power-off from an outage. I have not muted it. Muting would swap a false positive for a real blind spot. An expected-downtime design is open on the roadmap.

## The work desktop is untrusted on the tailnet

work01 is where I browse and install desktop software. It carries `tag:untrusted`, which gets internet only plus two grants scoped to named hosts. Leaving it untagged would put it in `autogroup:member` and give it full reach into infrastructure.

## No infrastructure-to-infrastructure grant

Nothing on `tag:infra` can reach anything else on `tag:infra` over the tailnet. Administration flows from my own devices to infrastructure, never sideways.

## Gaming moved off this host

Three gaming VMs were retired. The host's job is work, local AI, editing and labs. Removing gaming also removed Discord and game launchers from the estate and simplified GPU sharing to two VMs.

## A game library on the desktop, on a disk with no backup

In October I put a game library back on the work desktop, which partly reverses the decision above. The gaming VMs stay retired and Discord stays blocked. The library sits on its own virtual disk with Proxmox's `backup=0`, because games can be downloaded again from the store and would otherwise make the desktop's backup more than ten times larger. [Case study 19](case-studies.md#19-a-desktop-backup-that-grew-from-24-to-447-gib).

## Infrastructure as code dropped

I ran Terraform against the Proxmox API in a dedicated container and retired it in October 2026. The estate is one node with a small number of hand-built guests, and my target is endpoint management, not DevOps. The container and its state were archived. The Terraform files are not in this repo yet, so I make no claim about them here.

## Automation stack retired

n8n, a regression watcher, a container-image update watcher and an Uptime Kuma instance were retired together. Before removing n8n I checked what called into it, not only what ran on it. One active workflow was receiving webhook calls from an undocumented Uptime Kuma instance.

## Lab endpoints are disposable, tenant objects are the evidence

The Autopilot lab VM has no scheduled backup. Its value lives in the Intune and Entra objects and the captured evidence. Rollback uses per-lab snapshots. Teardown order matters: delete the Intune record, deregister from Autopilot, then remove the Entra object, then destroy the VM. Deleting the VM alone leaves a registration keyed to a serial that no longer exists.

## One Mac stays unenrolled

The MacBook is deliberately unmanaged. It is the negative case for the require-compliant-device policy. With every device compliant, there is no way to show the policy blocking anything.

## The iPhone gets app protection, not enrolment

It is a personal phone. App protection on Outlook, Teams and Edge plus a Conditional Access requirement keeps work data inside managed apps without putting the device under management. It also gives the tenant a real BYOD scenario next to the managed Windows, macOS, Android and Linux devices.

## CA001 targets Office 365, not all resources

Requiring a compliant device for all resources includes the Entra and Intune admin portals. A mistake in the policy could lock me out of the tools needed to undo it.

## The NAS service mailbox is excluded from Conditional Access

The NAS authenticates from a device that will never be compliant. Without the exclusion, NAS alerting fails silently. The mailbox has interactive sign-in blocked.

## The BitLocker cipher mismatch is left in place on the lab device

Moving the lab VM to XTS-AES 256 needs a full decrypt and re-encrypt. The finding is the mismatch and Intune's silence about it. The real fix is policy ordering during ESP, which matters on the next device, not this one.

## No false licence attestation

Remediations needs Windows Enterprise per user. The portal lets any tenant tick a box attesting to that licence. I bought the licence instead. The same rule applies to Secure Score: I do not mark an action as resolved by a third party or alternate mitigation unless one really covers it.

## SAML SSO for the NAS is a learning exercise

The NAS already has a password and TOTP. Entra SAML sign-in to it is for hands-on federation practice. It does not work yet, and nothing depends on it.

## Single-variable changes on hardware faults

When the GPU riser fault pointed at link speed, a second suspect sat in the same BIOS screen. I changed one setting and left the other until the first result is in. A clean result with two possible causes teaches nothing.

## Double NAT behind the shared ISP router

The ISP router belongs to the household and other people use it, so modem mode is not mine to choose. The gateway sits behind it and everything I own is behind my own firewall. Double NAT costs inbound port forwarding, which I do not use, and IPv6 prefix delegation. Tailscale still connects directly through it.

## A distinctive private range for the LAN

The new LAN is a private /24 away from the default ranges consumer routers use. A Tailscale subnet route for a common range clashes with the local network on almost any network I connect from. A distinctive range avoids that, and later VLANs follow the same numbering.

## Re-adopt the switch and access point, do not migrate the controller

The estate has one switch and one access point, and Ubiquiti's guidance on moving a self-hosted site to a gateway console is thin. Factory reset and fresh adoption took minutes and left nothing half-migrated. The old controller container was stopped, not deleted, as the rollback, and set not to start at boot in the same step.

## Old addresses kept as second addresses until every check passes

The host and llm01 carried both the old and new address during the renumber. Any session over the old address survived each change, and every machine stayed reachable until the cleanup stage. Removing the old address was the last step, after nine verify gates.

## Content filtering stays in NextDNS, not on the gateway

Two filters in series make every blocked-site problem twice as hard to diagnose. The gateway forwards DNS to NextDNS over DoH, so LAN-only devices get the same filtering as the tailnet without a second filter.

## No port forwards and no standing VPN server

Tailscale is the only remote access path. A UniFi VPN server appears only in a time-boxed lab that ends with every server turned off. The brokered VPN found enabled on the gateway is to be turned off on the same principle.

## The lab VLAN cannot be reached from the main network

The default would let the main network start connections into Lab. Nothing there needs to: I manage the lab VM through the Proxmox console and Intune reaches it over the internet. Keeping the default block means a compromised lab device and a compromised main-network device cannot meet in either direction.

## The UPS shuts the host down early

The UPS's own thresholds were 5 minutes and 10 percent. Stopping two GPU VMs and waiting on network storage needs more. The shutdown now starts at 20 minutes of runtime or 30 percent charge. On a battery that gives about 60 minutes at normal load, that still leaves 40 minutes of running time first.

## One DNS token per host for certificate challenges

The Proxmox host got its own DNS token, scoped to one zone with DNS edit and zone read, rather than reusing the token shared by older services. Losing one host's token then exposes one host. The NAS still uses the shared token and is next.

## The gateway's mDNS proxy is off

On Auto it reflected service announcements from the main network into the lab VLAN, including device names, addresses and a serial number. My own devices all sit on one network, where mDNS works without a proxy. If a later phase puts speakers on an IoT network, the proxy goes to Custom with only those two networks named, never back to Auto.

## Client names match Tailscale names

Guests appear in UniFi under the same `pve-<guest>` names they carry on the tailnet, so one machine has one name across the gateway, Tailscale and the incident notes.

## The desktop VMs get a LAN zone that mirrors their tailnet tag

work01 and edit01 already carried `tag:untrusted` on the tailnet: internet, plus two named hosts. The Untrusted firewall zone applies the same rule on the LAN: SMB to the NAS, Tailscale packets to the same two hosts, nothing else on the main network. One trust decision, enforced at both layers.

## Discord is blocked with Block, not Reject

Block drops silently. On my own desktop that is fine, and it gives a probe nothing to read. For a client's users I would use Reject or a block page, so nobody mistakes a policy for a fault.

## The mDNS proxy is scoped to two networks and one service

Speakers on the IoT network need their announcements to reach the phone app on the main network. The proxy runs in Custom mode with only those two networks and the one service the app needs. Lab and Untrusted are outside its scope, and captures prove nothing reaches them. Auto, which reflected everything everywhere, stays off the table.

## The speakers get one control port in, nothing else

The speaker's own mDNS record names TLS on TCP 1443 as its control port. That is the single allow from the main network, with replies allowed back, and only to the two speakers. AirPlay would need another port plus a range of dynamic ports into IoT, so it stays off.

## Open WebUI gets its own container

The chat front end runs apart from the model host. Model experiments on llm01 never take the interface down, and the container can be rebuilt without touching the GPU VM.

## The replacement Mac is enrolled without Apple Business

Automated Device Enrollment needs Apple Business, and Apple Business verification needs a registered organisation that matches a D-U-N-S record. This lab has no registered organisation, and I will not claim one. So the replacement Mac becomes corporate-owned the way the Mac mini did: its serial is registered in Intune as a corporate identifier before first power-on, then it enrols through Company Portal. I record the gaps against ADE as gaps: a local admin can remove the management profile, Intune's macOS LAPS cannot manage the local admin account without ADE, and nothing enrols during Setup Assistant.

## Platform SSO with the Secure Enclave method

The replacement Mac uses Platform SSO with the Secure Enclave method: phishing-resistant, unlocked with Touch ID, and the local password stays local. Password sync is the only method that ties the Mac password to Entra, and I do not want that. Microsoft allows one SSO extension payload per device, so the Platform SSO policy targets its own group, which the Mac mini's older SSO extension profile excludes.

## The guest network uses the gateway's built-in guest zone

The Hotspot zone's built-in rules already block every private range and allow DNS and DHCP to the gateway. A custom zone would have meant writing and maintaining the same rules by hand. No captive portal: the SSID is password-protected and the portal adds nothing for a household. Client isolation is on.
