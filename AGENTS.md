# Codex Instructions

- Do not run builds, build commands, or compile checks unless the user explicitly asks for them.
- If verification is useful, suggest the relevant build command instead of running it independently.
- Write new code according to clean code principles: keep it simple, readable, well-named, focused, and consistent with the existing project style.

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
