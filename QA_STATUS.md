# Simulator verification checkpoint — 2026-11-23

## Fresh retry on 2026-11-23

The user requested progress again, so the failed workflow was retried and an alternate standard runner pool was tested with identical app, test and CI source.

- [Run 45033895417, attempt 2](https://github.com/davidpovarsky/hanlin-sidebar-qa/actions/runs/45033895417/attempts/2), commit `6848ed2`, was queued at 20:59 UTC. All three simulator jobs failed before any steps, with the same billing/spending-limit annotation. The device-package job was skipped.
- [Alternate run 45266039008](https://github.com/davidpovarsky/hanlin-sidebar-qa/actions/runs/45266039008), standard `macos-15` pool, commit `1dffb0a`, was dispatched at 21:05 UTC. A Git diff first confirmed that this documentation commit has identical `App`, `Tests`, `ci`, `project.yml` and workflow contents. Both iPad jobs failed before any steps with the same billing annotation. The ARM pool also reported a separate capacity-delay notice. Once those failures were confirmed, cancellation was requested for the remaining queued work.

Neither attempt compiled the repair, executed a simulator assertion or produced a new IPA. No billing settings, repository visibility or unrelated jobs were changed. Current connected devices still provide no existing Mac fallback. The execution blocker therefore remains unresolved.

## Current blocker

Repair commit: `6848ed2d21eff7df10374ae87b184c5ff7a49cd3`.

[Run 45033895417](https://github.com/davidpovarsky/hanlin-sidebar-qa/actions/runs/45033895417) ended before any runner steps. All three simulator jobs contain the same GitHub annotation:

> The job was not started because recent account payments have failed or your spending limit needs to be increased.

The annotation does not distinguish which account condition applies. The device-package job was skipped. The latest source therefore remains uncompiled and unverified at runtime. There is no new IPA from this commit.

No alternative Mac is currently connected: SentinelX exposes one Windows host; the other available remote devices are Windows and Linux. The repository has zero self-hosted GitHub Actions runners. Billing or an authorized Mac runner must be available before simulator execution can resume.

## Completed execution and evidence

Previous tested commit: `d7b93a116c68157f862c7f7b36427cb9d6af715f`.

[Run 45030049611](https://github.com/davidpovarsky/hanlin-sidebar-qa/actions/runs/45030049611) used Xcode 26.2 and iOS Simulator 26.2. All app/test targets compiled.

| Suite | Passed | Failed | Observed result |
| --- | ---: | ---: | --- |
| iPhone 16 | 2 | 7 | Pin/unpin and quick actions/library passed. Five tests stopped at hidden-sidebar accessibility assertions; search encountered the system keyboard introduction; New Chat received the wrong coordinate because of an inflated accessibility frame. |
| iPad | 4 | 5 | Search, New Chat/send, pin/unpin and quick actions/library passed. The same five hidden-sidebar accessibility assertions failed. |
| Actual iPad window resize | 0 | 1 | OS window changed from 1180 × 820 to 375 × 625.5. System window controls covered the sidebar toggle, preventing the narrow interaction phase. |

The passing pin/unpin test physically opened and closed Settings afterward on both devices. Full nested Settings, all gesture routes and all narrow-window interactions remain required in the next run.

## Diagnosed defects and repairs

1. **Sidebar accessibility containment.** Closed-sidebar screenshots showed fully closed content, but sidebar controls remained in the accessibility tree. Explicit `.accessibilityElement(children: .contain)` boundaries now precede the broad hit shapes on the sidebar, workspace and viewport. The closed-sidebar absence assertion remains in the tests.
2. **New Chat target bounds.** The synthesized physical tap was `(153.33, 438.5)`, the whole sidebar's center, while the visible plus was near `(276, 93)`. The tap landed on chat 2. New Chat and the toolbar toggle now have explicit 44-point plain-button hit regions. Tests reject oversized icon targets before tapping and save New Chat's exact pre-tap screen/hierarchy.
3. **Keyboard first-use UI.** The search screenshot showed the requested chat selected, with the system `UIContinuousPathIntroductionView` still visible. Tests now dismiss only the exact observed introduction through its own Continue button, then keep the genuine keyboard-dismissal assertion. Production search focus is cleared on closure and selection.
4. **iPad window-control overlap.** The resized window was `(403, 32, 375, 625.5)`; the toggle was `(422, 57, 28.5, 21)` and non-hittable under the traffic-light buttons. Custom top bars now use `containerCornerOffset(.horizontal, sizeToFit: true)` on iOS 26. Closed-state tests measure the full-width content itself rather than assuming a fixed toolbar x-position.

Apple API references:

- https://developer.apple.com/documentation/swiftui/accessibilitychildbehavior/contain
- https://developer.apple.com/documentation/swiftui/view/containercorneroffset(_:sizetofit:)

The original Settings data is unchanged: all seven categories and 27 destinations match the genuine supplied `My App 70.swiftpm`. The single transformed sidebar layer, 0.86-to-1 growth, fixed layer order and root simultaneous gesture are retained.

## Continuation

After the external execution blocker is resolved, rerun the failed workflow or dispatch `ios.yml` on the repaired source. Do not treat the current commit as validated because the preceding commit compiled.

The gate requires all nine ordinary tests on iPhone, all nine on iPad, and the strict actual-window resize test. The latter must reach narrow Settings navigation, switch interaction, search, chat selection, three gesture heights and restoration to a wide window. The ordinary gesture test also covers measured toolbar and focused-composer coordinates.

Inspect real failure attachments and iterate if needed. Do not replace strict assertions with skipped tests or diagnostic-only success. Only after all gates pass should the device Release job package the unsigned SideStore IPA, verify the actual `Payload/HanlinSidebarQA.app/Info.plist` path, ARM64 platform and executable permissions, and produce a SHA-256 and tested commit identifier.

The new workflow builds tests before booting the simulator and publishes lightweight review evidence separately from complete `.xcresult` and videos.

Remote evidence remains at `C:\Users\DAVID\Code\hanlin-sidebar-diagnostics\run45030049611`, outside the repository.
