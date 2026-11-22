# Hanlin sidebar prototype

A self-contained SwiftUI prototype based on the original **My App 70.swiftpm** supplied in this conversation. It preserves the original sidebar and settings hierarchy. The example actions are local demonstrations; this repository does not contain the original Hanlin backend or API integration.

## Navigation and layout

- One `HistorySidebar` contains its header, search, quick actions, library, chats, and Settings button.
- In compact windows the entire sidebar scales together from 0.86 to 1.0. The full-width chat remains above it and translates horizontally. The layer order stays constant.
- The visible chat strip continues accepting taps and horizontal drags. A single directional simultaneous gesture on the fixed viewport handles the reveal; vertical scrolling remains separate.
- Covered sidebar controls do not receive touches or appear in accessibility. The existing toolbar control exposes the open/closed state.
- iPad windows at least 640 points wide use two columns; smaller iPad windows and iPhones use the sliding reveal. The physical-left reveal is retained in RTL while sidebar contents follow the locale.
- The application targets both iPhone and iPad, supplies a launch screen, supports all four iPad orientations, and omits the deprecated `UIRequiresFullScreen` compatibility key.

## Build and simulator QA

Generate the Xcode project with `xcodegen generate`. The deployment target is iOS 17.0. The GitHub workflow selects an installed Xcode whose SDK matches an installed simulator runtime, rather than using an older runner default.

The workflow runs independent iPhone, iPad, and actual iPad-window tests. Assertions cover visible state transitions, physical coordinate taps and drags, nested Settings navigation and dismissal, search and software keyboard, chat selection and creation, sending a local message, all quick actions, library, pinning, RTL, vertical scrolling, and rotation.

The iPad-window gate uses Settings and OS window controls to shrink the real application window below 640 points, checks compact layout and interaction in that window, then restores it. No test-only view width substitutes for system resizing. The diagnostic selector only collects evidence and is not a passing resize gate.

Results include `.xcresult`, screenshots, accessibility hierarchies, simulator/Xcode versions, and a structured summary. Packaging depends on every required UI job passing. A build alone, zero executed tests, skipped tests, or a diagnostic-only run does not satisfy the gate.

## IPA for SideStore

The device Release build is made on macOS from the same commit tested by the workflow. It is deliberately unsigned so SideStore can sign it with the installing account. Packaging preserves the macOS executable permissions and the ZIP path `Payload/HanlinSidebarQA.app/Info.plist`. The workflow verifies that path, checks device platform and ARM64 architecture, validates the built Info.plist, and includes a SHA-256 and tested commit identifier beside the IPA.

Simulator QA verifies the prototype interactions; installation through an individual SideStore account and frame pacing on physical hardware require that hardware. Test evidence should always be associated with its exact Git commit and workflow run.
