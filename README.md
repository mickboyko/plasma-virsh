# plasma-virsh
widget to lightly manage virtual machines using a plasma desktop widget

## Install
    kpackagetool6 -t Plasma/Applet -i package   # or -u to upgrade

Lists `virsh list --all` (polled every 5s) with a Start button for shut-off
domains (`virsh start`) and a Stop button for running ones. `virsh` has no
`stop` command, so Stop runs `virsh shutdown`. The widget has no background and
uses a shadow so theme text colour stays readable.
