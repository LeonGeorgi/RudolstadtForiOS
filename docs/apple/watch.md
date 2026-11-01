# Watch infrastructure

The Watch app and its Widget extension deploy to **watchOS 11.0**. This is the
Watch-generation counterpart to the companion app's iOS 18.0 deployment target
and keeps the targets available to the same device generation.

The iPhone remains the authority for festival and profile data. It sends one
versioned, complete LZFSE-compressed snapshot through
`WCSession.updateApplicationContext`. The encoded payload is capped below the
WatchConnectivity application-context budget; oversized future festival data is
rejected and logged instead of replacing a valid Watch state.
The Watch validates the schema, festival year, environment, revision, and stable
payload invariants before atomically replacing the last confirmed file.

Both the Watch app and Widget read
`confirmed-festival-snapshot-v1.lzfse` from the Watch-side App Group
`group.de.leongeorgi.RudolstadtForiOS.watch`. App Groups do not cross devices;
WatchConnectivity is the only iPhone-to-Watch transport. Preview, test, and
screenshot snapshots are never accepted by the production repository.

The Widget projects the next saved event from that same confirmed snapshot. It
precomputes entries only for known event and freshness boundaries, while SwiftUI
date styles update countdown text without minute-by-minute reloads. A confirmed
new snapshot revision reloads only the next-event widget kind.

`PersonalPlan` and `PlanFreshnessPolicy` in the common Kotlin module own the
next-event selection, timeline boundaries, daily plan, conflict/transition
selection and data-age decisions. Both native surfaces use these same rules.
`WatchNextEventTimeline.swift` adapts the persisted transport snapshot and the
result IDs to native presentation values; it does not recalculate plan rules.
The compressed wire format, App Group files, WatchConnectivity, WidgetKit and
SwiftUI remain native and keep their existing schemas and lifecycle behavior.

The shared library provides `watchosArm64` (arm64_32), `watchosDeviceArm64`,
`watchosSimulatorArm64` and `watchosX64` frameworks. The last target supplies the
Intel simulator architecture still requested by Xcode; Kotlin marks it deprecated.
Both Watch targets use the same `Build Kotlin Core` script as the iPhone app and
link the static `RudolstadtCore` framework. No Android application is created.

The rectangular family serves the Smart Stack and rectangular complications;
circular and inline families cover smaller complications. Event identity and
stage details are privacy-sensitive and are replaced with a generic locked state
when the system requests privacy redaction. Widget URLs include both festival
year and stable event ID; the Watch app validates both and falls back to its root
when changed festival data no longer contains the event.
