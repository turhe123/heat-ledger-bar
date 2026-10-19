# HeatLedgerBar — specification

**Tagline:** Log how long your Mac spends in each thermal state each day and show which apps were running when it got hot.

**Category:** System Monitoring

**Inspired by (paid):** Sensei ($29/year or $59 one-time)

**Frameworks:** SwiftUI, AppKit, Charts, UserNotifications, ServiceManagement

**Donation URL (Support button):** https://ko-fi.com/leodavidai

## Spec

What the paid app does and demand: Sensei is a Mac performance and monitoring suite priced at 29 dollars per year or 59 dollars one-time for three Macs, and a 2026 review of iStat Menus alternatives names it the best overall paid option while noting it needs macOS 14 or later. Among its hardware views is a temperature and thermal picture of the Mac, which people use to find out why a laptop gets hot or slow. Our clean-room version avoids private sensors and instead builds a day-by-day record of the official thermal state, which is different from a live temperature readout, and shows which apps were frontmost when heat built up.

Feature set: the app records every change of the system thermal state, which has four levels called nominal, fair, serious and critical, with timestamps. A daily bar shows the share of time in each state. A culprits list shows, for each hot period, the frontmost app and the three heaviest apps by name, so the user can see that for example a video export caused the heat. A weekly view compares days. A threshold notification can fire when the state stays at serious or critical for more than a chosen number of minutes, with the suggestion to close the named heavy app. History can be cleared, and data older than thirty days is dropped.

UI spec: a MenuBarExtra in window style. The label is a thermometer glyph tinted by current state: gray nominal, yellow fair, orange serious, red critical. The popover shows the current state in words, today's stacked bar made with Charts, and the last three hot periods with their culprit apps. A View History button opens a window with a seven and thirty day picker and a day table. Settings fields: alert after minutes (5, 10, 20), alert level (serious or critical), retention days and Launch at login. Empty state before any heat says Your Mac has stayed cool today, with a green check.

Technical approach: read Foundation ProcessInfo thermalState on start and observe the thermal state change notification. On each change, close the previous interval and open a new one, and store the intervals as JSON in Application Support, written atomically. Record the frontmost application from NSWorkspace at the moment of change and track activation changes while hot. To find heavy apps sample per-process CPU time using the Darwin proc_pid_rusage function once every ten seconds only during fair or worse states, and keep the top three by delta. Charts draws the bars. Alerts use UserNotifications. Launch at login uses SMAppService. No privacy permissions are needed.

Edge cases: the Mac may sleep during an interval, so close open intervals on the system will sleep notification and open a new one on wake. If the app launches while already hot, start the interval at launch time and label it as partial. Handle clock changes by ignoring negative durations. Cap stored culprit lists to five entries per interval. Prevent alert spam by sending at most one notification per hot period and rearming after a return to nominal.
