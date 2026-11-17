## QML Code Review Report

**Scope**: plugin/LockView.qml, plugin/LightTrail.qml, plugin/Ethereal.qml; Service.qml inspected as caller/context and compared to upstream baseline
**Files reviewed**: 3 presentation files (595 lines), plus service integration context
**Issues found**: 7 lint notices, 0 remaining confirmed defects from deep analysis
**Agents**: 0 (inline)
**qmllint**: ran, native Qt 6.12.0; no diagnostics for presentation files

### Lint findings

| Rule | Count | Locations | Mitigation / disposition |
|---|---:|---|---|
| BND-2 | 1 | LockView.qml:78 | Intentional stock password synchronization; TextInput.text has no competing declarative binding. |
| ORD-1 | 3 | LockView.qml:234,267,349 | Attached Accessible properties precede assignments in Qt qmlformat output; formatting only. |
| PRF-3 | 2 | LightTrail.qml:9, LockView.qml:356 | Clipping is required to contain the stripe and masked input. |
| STY-3 | 1 | LockView.qml:351 | Existing Omarchy dot-notation style for anchors. |

### Deep analysis findings

A1-A7 applied inline. No newly introduced QML logic: presentation, authentication
and helper files were transferred byte-for-byte. Reviewed both real-lock and
preview callers, shared password synchronization, mask/focus and animation
connections. Service.qml still differs from the recorded stock source by two
userName display bindings only. No authentication or session-lock function changed.

### Investigation targets (human verification needed)

Real password authentication, idle/suspend/DPMS, physical fingerprint and monitor
hotplug, and GPU frame timing require owner/hardware acceptance. Tests instantiate
only the presentation; the service compilation check does not instantiate PAM.

### Summary

| Category | Lint | Deep | Total |
|---|---:|---:|---:|
| Intentional synchronization | 1 | 0 | 1 |
| Required clipping | 2 | 0 | 2 |
| Formatting | 4 | 0 | 4 |
| **Total** | **7** | **0** | **7** |

## Ponytail review

What this change does: gives the plugin its own identity and Git repository. The
installer deploys copies, archives old files outside the project and restores
stock before replacing a disabled plugin. Rollback uses the same guarded entrypoint.

Reviewed the installer, rollback wrapper, test double and tests, verification
script, manifest, documentation and source/baseline differences. Expected load is
one desktop owner applying one installation at a time; simultaneous installers
are not supported. No new dependency, system service or network request was added.

A regression test exposed a recovery bug: requiring the new service's PAM-ready
flag before restoring stock could prevent recovery even while session-lock flags
were all false. Recovery now requires all unlocked flags but does not require a
ready PAM in the failed service. The reproducer and optimized-Python guard pass.
Unknown or locked states still stop all plugin switching.

Fresh/repeated deployment, rollback, error recovery and filesystem protection are
covered by nine isolated tests. Actual update and rollback were also exercised
while unlocked. No full repository audit was performed; there was no existing
Graphify graph to update.

Verdict: Ship.

Not checked: real password/PAM, suspend/DPMS, physical hotplug and FPS.
