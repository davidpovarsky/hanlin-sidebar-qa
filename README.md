# Hanlin sidebar prototype

A self-contained SwiftUI prototype based on the original **My App 70.swiftpm** supplied in this conversation. It preserves the original sidebar and settings hierarchy. The example actions are local demonstrations; this repository does not contain the original Hanlin backend or API integration.

## Verification and release gate

The current delivery path runs native compilation, simulator tests and unsigned device packaging on the Scaleway Mac. A release is qualified only when the original iPhone 9, iPad 9 and actual iPad-window 1 cases all pass on the same source commit, with zero failures or skips. A successful build or results from an older source revision do not satisfy this gate.

Release evidence identifies the tested commit, toolchain, actual case identities, device/runtime, screenshots and raw results. The SideStore package is accompanied by its SHA-256, bundle verification and complete matrix receipt. Installation and frame pacing on a physical iPad remain separate observations.

Earlier repairs, GitHub runner failures and diagnostic results are retained in [QA_STATUS.md](QA_STATUS.md) as historical evidence; they are not a qualification of a newer release.

## Navigation and layout

- One `HistorySidebar` contains its header, search, quick actions, library, chats, and Settings button.
- In compact windows the entire sidebar scales together from 0.86 to 1.0. The full-width chat remains above it and translates horizontally. The layer order stays constant.
- The visible chat strip continues accepting taps and horizontal drags. A single directional simultaneous gesture on the fixed viewport handles the reveal; vertical scrolling remains separate.
- Covered sidebar controls do not receive touches or appear in accessibility. The existing toolbar control exposes the open/closed state.
- iPad windows at least 640 points wide use two columns; smaller iPad windows and iPhones use the sliding reveal. The physical-left reveal is retained in RTL while sidebar contents follow the locale.
- The application targets both iPhone and iPad, supplies a launch screen, supports all four iPad orientations, and omits the deprecated `UIRequiresFullScreen` compatibility key.
- Custom top bars use the iOS 26 corner-inset API to avoid system window controls, with compiler and availability guards for older Swift Playgrounds SDKs.

## Build and simulator QA

Generate the Xcode project with `xcodegen generate`. The deployment target is iOS 18.0, the minimum for the public `UIGestureRecognizerRepresentable` API that attaches the sidebar pan to its SwiftUI viewport. SwiftUI owns its lifetime and action delivery; the effect does not install a recognizer on the shared `UIWindow`. The GitHub workflow selects an installed Xcode whose SDK matches an installed simulator runtime, rather than using an older runner default.

QA comprises independent iPhone, iPad, and actual iPad-window tests. Assertions cover visible state transitions, physical coordinate taps and drags, nested Settings navigation and dismissal, search and software keyboard, chat selection and creation, sending a local message, all quick actions, library, pinning, RTL, vertical scrolling, and rotation.

The iPad-window gate uses Settings and OS window controls to shrink the real application window below 640 points, checks compact layout and interaction in that window, then restores it. No test-only view width substitutes for system resizing. The diagnostic selector only collects evidence and is not a passing resize gate.

Results include `.xcresult`, screenshots, accessibility hierarchies, simulator/Xcode versions, and a structured summary. Packaging depends on every required UI job passing. A build alone, zero executed tests, skipped tests, or a diagnostic-only run does not satisfy the gate.

## IPA for SideStore

The device Release build is made on macOS from the same commit qualified by all three QA stages. It is deliberately unsigned so SideStore can sign it with the installing account. Packaging preserves the macOS executable permissions and the ZIP path `Payload/HanlinSidebarQA.app/Info.plist`. The workflow verifies that path, checks device platform and ARM64 architecture, validates the built Info.plist, and includes a SHA-256 and tested commit identifier beside the IPA.

Simulator QA verifies the prototype interactions; installation through an individual SideStore account and frame pacing on physical hardware require that hardware. Test evidence should always be associated with its exact Git commit and native run identifier.

## Actual-window gesture targeting

The original narrow-window fixture started a closing drag at 94% of the actual window width. At the OS-selected 375-point width, that position is only 22.5 points inside the physical right edge. Retained native diagnostic `a1ce6dc` recorded `UIWindowScene.effectiveGeometry.isInteractivelyResizing == true` before UIKit cancelled the touch; the video also shows the entire floating window compressing and returning. Those original failed runs remain failure evidence.

The fixture now starts at the horizontal midpoint of the actual `chat-history` frame intersected with the real OS window. It asserts that this exposed area is nonempty and that the start is inside it. The real narrow window, all three gesture heights, destination, press duration, close-state and layout assertions, subsequent interactions, and physical wide-window restoration are preserved. This correction changes the test's input target only; it does not suppress system window gestures or change the app's recognizer. The same 19 test identities must pass on the exact candidate before packaging.
