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
