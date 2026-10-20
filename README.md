# plasma-virsh

A lightweight KDE Plasma 6 widget for managing libvirt virtual machines with `virsh`.

## Features

- Lists all domains from `virsh -c qemu:///system list --all`, polled every 5 s.
- VMs are grouped into rounded **Running** and **Stopped** boxes.
- **Start** / **Stop** buttons per VM. `virsh` has no `stop`, so Stop runs
  `virsh shutdown` (a graceful ACPI shutdown). A spinner and "starting…" /
  "stopping…" label show until the next poll reflects the change. It clears on
  error or after 90 s.
- Each VM expands to show:
  - **Details:** IP address, allocated CPUs, RAM and disk capacity. The IP comes
    from the libvirt lease, falling back to the QEMU guest agent. It is blank for
    stopped VMs.
  - **History graphs** (running VMs only, last ~5 minutes): CPU %, memory %,
    network throughput and disk I/O, from `virsh domstats`.
- Transparent background with a shadow so theme text stays readable.

## Requirements

- Plasma 6, `virsh` in `PATH`
- Access to `qemu:///system` (usually membership of the `libvirt` group)

The connection URI is hard-coded to `qemu:///system`. Plain `virsh` defaults to
`qemu:///session`, which usually has no domains.

Notes:

- Memory % is the balloon allocation relative to the maximum, not in-guest usage.
- Net and disk graphs are rates calculated between polls, so they start after the
  second poll.
- IP lookup over a bridge needs `qemu-guest-agent` running in the guest.

## Install

    kpackagetool6 -t Plasma/Applet -i package   # or -u to upgrade

Then add "Virsh Domains" via **Add Widgets…**. After an upgrade, restart the
shell with `plasmashell --replace`.

## Development

Run without installing:

    plasmawindowed package

## Layout

- `package/contents/ui/main.qml`: polling, parsing, and state
- `package/contents/ui/VmGroup.qml`: rounded group box
- `package/contents/ui/VmRow.qml`: VM row and expandable details
- `package/contents/ui/Graph.qml`: sparkline
