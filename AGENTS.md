# Codex Instructions

- Write new code according to clean code principles: keep it simple, readable, well-named, focused, and consistent with the existing project style.

## Build and verification

- After changing code, you may run the smallest relevant non-destructive compile check or targeted test.
- Do not run clean builds, full builds, full test suites, simulator builds, or launch the app without explicit user authorization.
- Respect explicit requests not to build or test.
- Report which verification was performed and which relevant verification remains outstanding.

## Working approach

- Before changing code, inspect the relevant implementation, its callers, and nearby conventions. Do not guess when the repository can answer the question.
- State assumptions when they materially affect behavior, architecture, or scope. Ask the user only when the uncertainty cannot be resolved from the repository and different answers would lead to meaningfully different implementations.
- Define the observable outcome before implementing. For non-trivial work, identify how the result can be verified and keep implementation and verification aligned with that outcome.
- Make the smallest coherent change that fully solves the requested problem. Do not expand the scope with speculative features, unrelated cleanup, or preventive abstractions.
- Preserve existing behavior unless changing it is part of the request. When requirements conflict with current behavior, surface the conflict explicitly.
- Before handing off, review the diff for unintended changes, unresolved assumptions, duplicated logic, and missing relevant states. Report what was and was not verified.

## Code quality

- Prefer simple, explicit solutions over clever abstractions. Add abstractions only when they clarify responsibilities or remove meaningful duplication.
- Treat a smaller codebase as a meaningful quality advantage. Prefer changes that remove code and obsolete complexity, and justify additions by the value they provide. Never reduce code at the expense of clarity, correctness, or maintainability.
- Keep components focused, follow the existing architecture and conventions, and avoid unrelated refactoring.
- Model state and data flow clearly. Avoid force unwraps, hidden side effects, duplicated sources of truth, and silently ignored errors.
- Use structured, cancellation-aware Swift concurrency with clear task ownership and correct actor isolation.
- Add or update tests for non-trivial logic and regressions when practical. Test observable behavior, not implementation details.

## Product and UI quality

- Treat this as a polished consumer iOS app, not merely a functionally correct project.
- Target the design language and native APIs of iOS 26 and newer. Prefer standard SwiftUI behavior, system components, semantic colors, Dynamic Type, and familiar iOS navigation and interactions.
- Preserve the app’s distinctive festival identity and its useful custom experiences, especially the schedule timeline, artist imagery, and discovery features. Native does not mean generic.
- Keep interfaces focused, visually balanced, and consistent. Pay attention to hierarchy, spacing, alignment, typography, image treatment, content density, and all relevant states.
- Do not “improve” the design by automatically adding cards, rounded backgrounds, materials, gradients, shadows, glass effects, or custom controls. Add visual treatment only when it serves a clear structural or semantic purpose.
- Consider accessibility, localization, Dark Mode, different device sizes, and large Dynamic Type part of the design—not optional cleanup.
- For UI changes, inspect the existing screen first and preserve what already works. When the user has authorized running or building the app, verify the rendered result in the simulator; otherwise explain that visual verification remains outstanding and suggest the relevant command or workflow. Do not judge visual quality from source code alone.
- Prefer a small, well-justified improvement over an unnecessary redesign. If a change is primarily subjective, explain the trade-off before implementing it.

## Issue tracking

This project uses **GitHub Issues** in `LeonGeorgi/RudolstadtForiOS` for tasks,
follow-up work, planning, and dependencies. Use the connected GitHub integration
when available and `gh` as the command-line fallback.

- `gh issue list --repo LeonGeorgi/RudolstadtForiOS --state open` — list open work
- `gh issue view <number> --repo LeonGeorgi/RudolstadtForiOS` — inspect an issue
- `gh issue create --repo LeonGeorgi/RudolstadtForiOS ...` — create an issue
- `gh issue edit <number> --add-label status:in-progress` — mark work in progress
- `gh issue comment <number> --body "Note"` — record progress or context
- `gh issue close <number> --reason completed` — mark work complete
- `gh issue edit <number> --add-blocked-by <number>` — record a dependency
- `gh issue edit <number> --parent <number>` — assign a parent issue

Use native GitHub sub-issues for hierarchy and `blocked by` relationships for
dependencies. Use `priority:P0` through `priority:P4` labels, where P0 is highest,
and `type:bug`, `type:feature`, `type:task`, or `type:epic` labels for issue type.
Use additional topic labels as needed. Do not create a parallel local tracker or
ad hoc task list in repository files.

### User approval gate

- Every GitHub issue created by an agent or LLM must initially have the
  `needs-approval` label, together with appropriate type and priority labels.
- Only the user may approve an issue. Approval is represented by removing
  `needs-approval` and adding the `approved` label.
- Agents must not start, implement, or otherwise work on an issue unless it has
  the `approved` label and has no unresolved `blocked by` relationship.
- Before starting issue work, inspect the GitHub issue and verify that `approved`
  is present. If approval is missing, stop and ask the user for approval.
- The user explicitly requesting implementation of a specific issue counts as
  approval; update its labels to `approved` before starting work.
- When work starts, add `status:in-progress`. Record material progress as issue
  comments. When the work is complete, remove `status:in-progress` and close the
  issue as completed.

## Simulator screenshots of specific screens

Use this workflow when the user explicitly asks to run the app and capture a particular iOS screen. Prefer real UI navigation over adding launch arguments or other screenshot-only behavior to production code.

1. Prefer the installed XcodeBuildMCP and Maestro MCP tools over shell commands and coordinate-based UI clicking.
2. Use an iOS 26 simulator when reviewing Liquid Glass. Call Maestro's device-list tool first and reuse a connected simulator when suitable. Avoid leaving several simulators booted because CoreSimulator operations can hang.
3. If the requested app version is already installed and running, inspect and navigate it directly with Maestro; do not rebuild unnecessarily.
4. If a build or launch is required, first inspect XcodeBuildMCP's session defaults. Configure this project, the `RudolstadtForiOS (iOS)` scheme, the selected simulator, and bundle ID `de.leongeorgi.RudolstadtForiOS`, then use its simulator build-and-run workflow. Building is authorized only when the user explicitly requested running or rebuilding the app.
5. Always build with normal local simulator signing so CloudKit entitlements are embedded. Do not pass `CODE_SIGNING_ALLOWED=NO`; the app traps at startup without its CloudKit entitlement.
6. When launching specifically for screenshots, pass `-screenshotMode YES` if the launch tool supports app arguments. This mode prevents the notification permission dialog; it does not select or navigate to a screen.
7. For navigation, use the Maestro workflow `list devices -> inspect screen -> run flow`. Inspect the hierarchy before selecting elements, use exact visible text or stable accessibility identifiers, and re-inspect after navigation rather than guessing labels or coordinates.
8. Prefer one short inline Maestro flow for a multi-step navigation. Do not clear app state unless the task requires a fresh state, because doing so discards the user's current simulator state.
9. After reaching the requested screen, wait for animations and remote content, especially artist images. Inspect the screen again to verify the expected destination, then capture it with Maestro's screenshot tool. If the image is still a placeholder or partially rendered, wait and capture again.
10. Use XcodeBuildMCP's screenshot or `xcrun simctl io <UDID> screenshot /tmp/<name>.png` only as a fallback when Maestro cannot capture the screen. Use macOS Accessibility and coordinate-based clicks only as a last resort when semantic MCP navigation is unavailable.
11. Check `git status --short` before handing off. Simulator navigation and screenshots should leave the production worktree unchanged.
