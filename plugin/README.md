# Ethereal Glass Lockscreen

Omarchy shell plugin `ethereal.lock`, derived from the installed stock
`omarchy.lock` authentication service. `clonedFrom: omarchy.lock` gives the shell
its native replacement and rollback behavior. Password PAM, fingerprints,
session-lock protocol, DPMS, wallpaper cache/posters and recovery are preserved.

Visual settings are in `Ethereal.qml`. `LockView.qml` keeps stock password
masking, synchronization, focus restoration and wake-key repeat filtering.
`LightTrail.qml` reacts to user text edits and stores only the previous length.
An event-only dbus-monitor subscription refreshes the clock/focus on logind
resume while a surface is shown. There are no network requests.

Preview: `omarchy-shell lock preview`; click to close, or use
`omarchy-shell lock hidePreview`. Stock preview disables input and PAM.

Only while confirmed unlocked, restore stock with:

```sh
omarchy plugin disable ethereal.lock
omarchy plugin enable omarchy.lock
```

The repository contains guarded installation, update, rollback and verification
scripts. Installed files are copies, so editing the Git checkout does not
hot-reload a running lock client. Never edit installed QML while locked.

Baseline: Omarchy 4.0.0.r7967.g3b36b9e-1, Quickshell 0.3.2, Qt 6.12.0.
Service.qml differs from stock by two userName display bindings only. Clones do
not automatically receive upstream authentication fixes: compare the stock
service and helpers after every Omarchy update, update the recorded baseline,
rerun verification and install only while unlocked.
