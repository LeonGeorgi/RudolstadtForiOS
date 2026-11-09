# Coding Agent Instructions

## Project context

Rudolstadt is an unofficial SwiftUI client for the Rudolstadt Festival. This
directory contains the native Apple frontend of RudolstadtKMP.
Reusable domain code and festival resources live in `../shared`; native code here
is shared by the iOS and macOS targets. Treat it as a polished,
data-sensitive consumer app rather than a collection of independent screens.

- `Shared/App` owns composition, navigation, app state, Firebase adapters, and
  lifecycle behavior.
- `Shared/API` and `Shared/Data` own remote conversion, bundled festival data,
  persistence, and data access.
- `Shared/Core` contains the Swift adapters to the common Kotlin domain.
- Shared rules live in `../shared/src/commonMain/kotlin`; JSON stays at external
  source boundaries. Preserve recoverable errors and the existing persisted schemas.
- `Shared/Screens` contains feature UI; `Shared/SharedUI` contains genuinely
  shared presentation components.
- `Unit Tests` contains the fast domain, parsing, persistence, and service tests.
- The project deploys to iOS 18 and macOS 12.2. Design for current iOS 26
  conventions without breaking those deployment targets; guard newer APIs and
  provide an appropriate fallback.
- Preserve the bundled-data fallback and distinguish remote, cached, preview,
  and screenshot data explicitly. Do not turn failed loading into
  plausible-looking current festival data.
- Changes to saved events, ratings, user preferences, festival profiles, or
  Firebase sharing must consider migration, merge, offline, and partial-failure
  behavior. Never risk silently discarding user state.
- User-facing text must remain localized in German and English.

Write new code according to clean code principles: keep it simple, readable,
well-named, focused, and consistent with the existing project style.

## Build and verification

- Agent builds and tests must use an explicit, separate DerivedData directory
  (for example `/tmp/RudolstadtKMPStandaloneDerivedData`), since the user may
  build in Xcode at the same time. Never compile into Xcode's normal DerivedData
  directory. If its Swift packages are missing, resolve packages there without
  running a build against that directory.
- After changing code, you may run the smallest relevant non-destructive compile
  check or targeted test. The canonical unit-test route is the `Unit Tests`
  scheme with the `Fast Tests` test plan; narrow it with `-only-testing` when a
  focused test is sufficient.
- Select an available compatible simulator at runtime rather than hard-coding a
  device or OS patch version.
- Targeted unit tests are permitted without separate authorization. Do not run
  clean builds, the complete test plan, UI or screenshot tests, broad simulator
  builds, or launch the app without explicit user authorization.
- A launched simulator build must use normal local signing so its app
  entitlements are present. Never launch a build produced with
  `CODE_SIGNING_ALLOWED=NO`.
- Respect explicit requests not to build or test.
- Report which verification was performed and which relevant verification remains outstanding.

## Working approach

- Before changing code, inspect the relevant implementation, its callers, and nearby conventions. Do not guess when the repository can answer the question.
- Confirm the repository root and current branch, then check
  `git status --short`. Preserve user changes and unrelated work. Stay on the
  current branch unless the user explicitly requests otherwise.
- State assumptions when they materially affect behavior, architecture, or scope. Ask the user only when the uncertainty cannot be resolved from the repository and different answers would lead to meaningfully different implementations.
- Define the observable outcome before implementing. For non-trivial work, identify how the result can be verified and keep implementation and verification aligned with that outcome.
- Make the smallest coherent change that fully solves the requested problem. Do not expand the scope with speculative features, unrelated cleanup, or preventive abstractions.
- Preserve existing behavior unless changing it is part of the request. When requirements conflict with current behavior, surface the conflict explicitly.
- Do not introduce a new dependency when the repository can express the logic
  clearly without it.
- Push back when a requested or proposed approach would create avoidable scope,
  complexity, public API surface, or verification risk. Explain the concern and
  offer the smaller path that still satisfies the goal.
- Before handing off, review the diff for unintended changes, unresolved assumptions, duplicated logic, and missing relevant states. Report what was and was not verified.

## Code quality

- Prefer simple, explicit solutions over clever abstractions. Add abstractions only when they clarify responsibilities or remove meaningful duplication.
- Treat a smaller codebase as a meaningful quality advantage. Prefer changes that remove code and obsolete complexity, and justify additions by the value they provide. Never reduce code at the expense of clarity, correctness, or maintainability.
- Keep components focused, follow the existing architecture and conventions, and avoid unrelated refactoring.
- Model state and data flow clearly. Avoid force unwraps, hidden side effects, duplicated sources of truth, and silently ignored errors.
- Use structured, cancellation-aware Swift concurrency with clear task ownership and correct actor isolation.
- Keep pure festival, recommendation, date, and schedule calculations separate
  from SwiftUI, Firebase integration, persistence, networking, and the system clock so they
  remain deterministic and testable.
- Preserve availability behavior across supported targets. Do not solve a new
  SDK warning by silently raising the deployment target or removing a fallback.
- Add or update tests for non-trivial logic and regressions when practical. Test observable behavior, not implementation details.

## Product and UI quality

- Treat this as a polished consumer iOS app, not merely a functionally correct project.
- Target the design language of iOS 26 while preserving the configured iOS 18
  deployment target. Prefer standard SwiftUI behavior, system components,
  semantic colors, Dynamic Type, and familiar navigation and interactions.
- Preserve the app’s distinctive festival identity and its useful custom experiences, especially the schedule timeline, artist imagery, and discovery features. Native does not mean generic.
- Keep interfaces focused, visually balanced, and consistent. Pay attention to hierarchy, spacing, alignment, typography, image treatment, content density, and all relevant states.
- Do not “improve” the design by automatically adding cards, rounded backgrounds, materials, gradients, shadows, glass effects, or custom controls. Add visual treatment only when it serves a clear structural or semantic purpose.
- Consider accessibility, localization, Dark Mode, different device sizes, and large Dynamic Type part of the design—not optional cleanup.
- For UI changes, inspect the existing screen first and preserve what already works.
  When app launch is authorized, verify the updated app in the simulator. For
  small changes, a brief visual check of the affected screen and relevant state
  is sufficient. If app launch is not authorized, report that the visual check
  is pending and point to the relevant workflow. Do not judge visual quality
  from source code alone.
- Use the full Sketch comparison in `../docs/screenshots.md` only for a targeted
  design review against Sketch.
- Prefer a small, well-justified improvement over an unnecessary redesign. If a change is primarily subjective, explain the trade-off before implementing it.

## Issue tracking

This project uses **GitHub Issues** in `LeonGeorgi/RudolstadtForiOS` for tasks,
follow-up work, planning, and dependencies. Use the connected GitHub integration
when available and `gh` as the fallback. Do not create a parallel local tracker.

- Use native sub-issues for hierarchy and `blocked by` relationships for
  dependencies. Use `priority:P0` through `priority:P4` and one of `type:bug`,
  `type:feature`, `type:task`, or `type:epic` on agent-created issues.
- Every agent-created issue starts with `needs-approval`. Only the user may
  approve it by replacing that label with `approved`.
- Do not implement an issue unless it is approved and unblocked. The user
  explicitly requesting implementation of a specific issue counts as approval;
  update its labels before starting.
- Add `status:in-progress` when issue work starts, record material progress in
  comments, and remove the status and close the issue when the work is complete.

## Simulator screenshots of specific screens

Use this workflow only when the user explicitly asks to run the app and capture
an iOS screen. The canonical App Store capture workflow and its options live in
`../docs/screenshots.md`; do not duplicate or override it here.

- Prefer an already booted suitable iOS 26 simulator and an already installed
  app. Avoid unnecessary builds and avoid leaving multiple simulators booted.
- For automated captures, use the `Native Screenshots` scheme, bundle ID
  `de.leongeorgi.RudolstadtForiOS`, and normal simulator signing.
- Use `-screenshotMode YES` only when deterministic seeded screenshot state is
  intended. It loads bundled festival and news backups, disables network
  refreshes and Firebase, resets screenshot-relevant preferences, seeds profile
  and friend data, and suppresses permission interruptions. It does not navigate
  to the requested screen.
- Prefer semantic XCTest navigation over coordinates. Inspect before acting,
  use visible text or stable accessibility identifiers, and verify the hierarchy
  again after navigation. Do not add screenshot-only navigation behavior to
  production code.
- Do not clear app state unless the task requires it. After navigation, wait for
  animations, images, and map content, verify the destination, then capture.
- Use lower-level simulator screenshots or coordinate-based macOS interaction
  only when semantic tooling cannot complete the task.
- Check `git status --short` before handing off. Screenshot work should leave the
  production worktree unchanged.

## Agent skills

### Issue tracker

Engineering skills use GitHub Issues in `LeonGeorgi/RudolstadtForiOS`.
Read `../docs/agents/issue-tracker.md` before tracker operations.

### Triage labels

Use the five canonical triage labels. Read `../docs/agents/triage-labels.md`
before triaging; triage readiness does not grant implementation approval.

### Domain docs

Use a single-context layout. Read `../docs/agents/domain.md` before
exploring the domain.
