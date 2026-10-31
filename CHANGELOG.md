# Changelog

All notable changes to this widget. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

Changes that come from someone else (a merged pull request, or an issue or report that led to
the change) are credited at the end of their line as `(#N, thanks @handle)`.

## [Unreleased]

### Added

- Presets card (Tracking tab, switch `cardPresets`): the camera's three preset slots with name and
  pose, Recall, Save current pose, Rename and Delete (with a confirmation). While zone tracking
  follows new targets the card says that a recall makes the next zone return end in Static.
  A failed or lost read shows "Could not read the presets" with a retry (#65).
- Framing card: "Use current pose as start pose" and "Go to start pose" for the pose the camera
  takes at power-on, with the stored start pose shown when obsbot4linux reports it (#66).
- Camera card: read-only info line with firmware, anti-flicker, frame rate, digital zoom and
  wake-up zoom; a value the installed obsbot4linux does not report is left out (#67).

- Audio card: microphone volume slider; Camera card: status LED blink switch (the camera cannot
  report it, so it shows the last value set from the widget). Each shows only with obsbot4linux
  0.10 or newer (#74).
- Sleep card: wake-up zoom and start mode on wake, set in the camera. With `wake_mode` the
  widget no longer applies the "Tracking mode on wake" setting itself; older obsbot4linux keeps
  the old behaviour. Whether the camera applies the start mode on wake, on power-on or both is
  not tested yet, so the old setting stays for now (#75).
- Picture card: autofocus mode (Continuous / Single / Manual) with a manual focus slider, and a
  click on the running preview (popout and desktop widget) focuses once on that spot. Behaviour
  with mirror or invert on is untested (#76).

## [0.21.0] - 2026-10-31

### Added

- "Show target box in preview" in the Tracking card: draws the box of the person the camera
  tracks over the preview, in the popout and in the desktop widget; green while the camera has
  the target, warning colour while it searches. Off by default. The box follows at most once a
  second (#63).

### Fixed

- The zone hint and the README no longer say that the camera may go Static after the target
  leaves the area: obsbot4linux 0.7.3 fixed that (it came from its pose polling,
  nofuturekid/obsbot4linux#67).

## [0.20.1] - 2026-10-31

### Fixed

- Quick presses of the arrow keys fell short (four presses from 0 ended at 14.9 instead of 20):
  each press added the step to the live pose, which since obsbot4linux 0.7.3 is the gimbal's real
  position on the way to the previous target. While an own move is under way (2 s after the last
  press) the arrows now build on the target that was sent (#61).

## [0.20.0] - 2026-10-31

### Changed

- With obsbot4linux 0.8.0 or newer the widget asks for the live gimbal pose only while the popout
  with the Framing card is open (`live-pose on` / `off` over the watch connection, again after the
  watch restarts), so the daemon stops polling the camera otherwise. The desktop widget never asks.
  Older obsbot4linux versions are unaffected. (#58)

### Fixed

- The Framing card's left and right arrows follow the picture: with mirror on they pan the other
  way, so left shows more of the picture's left edge. "Invert view and gimbal" needs no extra
  flip (measured: the reported pan equals the commanded one with invert on and off). (#59)

## [0.19.1] - 2026-10-28

### Fixed

- plugin.json now states the obsbot4linux version the widget actually requires, 0.7.1 (the startup
  check already refused older ones; plugin.json still said 0.5.0).

## [0.19.0] - 2026-10-28

### Changed

- **Breaking:** the repository is renamed from `dms-obsbot-control` to `obsbot4linux-dux`, next to
  obsbot4linux, and the plugin id from `obsbotControl` to `obsbot4linuxDux` (install folder,
  settings key, bar widget). The widget keeps its name, OBSBOT Control. To move an installed copy:
  remove the `obsbotControl` plugin, install `obsbot4linuxDux`, add the widget to the bar again
  (its settings start fresh). GitHub redirects the old repository URL.

## [0.18.1] - 2026-10-27

### Changed

- The pan/tilt buttons, the zone sliders and the zoom take their ranges from obsbot4linux's
  `limits` instead of their own (#53). Requires obsbot4linux 0.7.1.
- Tilt stops at -70 instead of -89: below -75 the Tiny 2 Lite goes to sleep, and woken there it
  sleeps again. The zone area reaches pan ±150 and tilt -70..90 instead of ±100 / ±30 (#53).

## [0.18.0] - 2026-10-27

### Added

- Errors from obsbot4linux show as a DMS toast, also with the popout closed and from the
  desktop widget. Before, they were only logged and the control snapped back (#42).
- Each instance logs once what it is and on which screen ("started as bar widget on screen
  DP-1", "desktop widget …", "Control Center tile or detail page"), and when its video node
  is found or lost (#37).
- `watch` logs its stderr and exit code (#45).

### Changed

- The pan/tilt buttons reach obsbot4linux 0.7.0's gimbal range, pan ±150 and tilt -89..90,
  instead of ±130 / ±90. A step down to -90 was rejected by 0.7.0 (and flipped the camera to
  +90 with 0.6.0) (#41).
- A failed request rolls back only its own change; other changes in flight stay (#42).
- `watch` restarts back off from 2 s to 30 s while it keeps failing (#45).
- The preview's camera exists only while the preview runs, so "Stop" frees the device for a
  call while the popout stays open. Without a matching device no preview is built instead
  of falling back to another camera, e.g. a laptop's (#44).
- The "Follow new targets" texts state what was measured: with the zone return position at
  0/0/1.0 the camera went Static after the target left the zone (#47).

### Fixed

- The "Direction change" gesture switch sent `direction`, which obsbot4linux does not accept,
  so it could never be changed (#40).
- With one bar per screen, every instance sent the wake tracking mode; now one does (#43).
- The throw-away instance DMS creates for the Control Center icon no longer starts a `watch`
  (#45).
- Zone sliders no longer jump back while dragged or right after sending, and a cancelled drag
  can no longer leave them ignoring the camera (#46).
- "On air: preview" no longer stays on when the camera goes to sleep with the popout open
  (#44).

## [0.17.1] - 2026-10-26

### Fixed

- With the bar widget (or the desktop preview) on several screens, the preview stayed at
  "Waiting for the camera" on all screens but one. All instances resolved the camera's
  video device with the same `Proc` id, and `Proc` keeps only the last callback per id.
  Each instance now gets its own.

## [0.17.0] - 2026-10-25

### Changed

- The popout keeps Preview and Framing in the left column, always visible, so the picture
  can be watched while changing settings. The right column is a tab bar: Tracking
  (Tracking, Zone), Picture (Picture, Image) and Device (Camera, Sleep, Audio, Gestures,
  Factory reset). The tab area is as high as the tallest tab, so the popout does not jump
  when switching. The last selected tab is remembered (`lastTab`). A tab without cards
  (switched off or unsupported) drops out of the tab bar.
- Arrange mode reorders cards within a tab and moves them to another tab by dropping them
  on its tab button. Preview and Framing are fixed. The order is saved per tab as
  `cardTabs`; "Reset layout" restores the default.
- The popout is 920 px wide instead of 760, the left column takes 55 % of it: a larger
  preview.
- Collapsible cards: one open per tab; switching tabs closes it. When the screen is too
  low, only the tab content scrolls; Preview and Framing stay in place (the preview gets
  flatter if needed).
- A saved `cardOrderLeft` / `cardOrderRight` order becomes the tab order: every card goes
  to its default tab, ordered by its place in its old column. Cards missing there join
  their default tab at the end. The old keys are ignored and removed by "Reset layout".

## [0.16.0] - 2026-10-25

### Added

- Zone card: "Go to return position" moves the camera to the zone return position, and
  a line shows that position (pan, tilt, zoom) as the camera reports it.

### Changed

- The Zone card shows the area the camera reports (obsbot4linux 0.5.0) instead of the
  last one the widget set; the plugin setting `zoneArea` is no longer used.
- Needs obsbot4linux 0.5.0 or newer.

### Fixed

- "Return here" moved the camera to its start pose instead of setting the zone return
  position (#29). With obsbot4linux 0.5.0 it stores the current pose.

## [0.15.0] - 2026-10-25

### Added

- Desktop widget with the camera preview (a second surface of the plugin, which is
  now a composite plugin and needs DMS 1.5.0 or newer). Same overlay as the popout:
  preview off shows the hint with Start preview / Wake camera / Retry, preview on
  shows the live picture and hovering offers "Stop preview". 16:9 picture fitted in
  a freely placed and resizable widget (minimum 240 × 135 px). It never starts by
  itself and stops when the camera sleeps or is unplugged, or when DMS unloads the
  widget (switched off, removed, desktop being edited); a small red dot marks a
  running preview. It runs its own `obsbot4linux watch`.
- One preview at a time: starting the preview on the desktop switches the popout's off
  and the other way round. The bar icon's on-air dot and the header's "On air:
  preview" count the desktop preview.

### Changed

- The preview frame (picture, hint, hover overlay) moved from `PreviewPane` into
  `PreviewFrame`, shared by the popout card and the desktop widget; the popout looks
  and behaves as before.

## [0.14.0] - 2026-10-25

### Added

- Zone card (left column, last; only for cameras with zone tracking): a switch for
  "Zone tracking" (read back from the camera), the area as pan from/to (-100 to
  100°) and tilt from/to (-30 to 30°) sliders that send `zone area` once released,
  "Full area", and "Return here" (the current pose becomes the position zone
  tracking returns to). A hint explains what happens when the target leaves the
  area: without "Follow new targets" tracking switches to Static and the camera
  returns to the return position; with it, the camera keeps tracking and takes the
  next person who enters the area (both measured on a Tiny 2 Lite). The camera
  cannot report the area, so the widget shows the last one it set (plugin setting
  `zoneArea`). Card switch `cardZone`.
- Tracking card: "Follow new targets" (it works with and without zone tracking:
  the camera keeps tracking and waits for a new target instead of switching to
  Static; the switch shows the value obsbot4linux remembers).
- Status line, tooltip and Control Center tile say "searching" while the camera
  tracks but has lost its target (obsbot4linux 0.4.0 reports it; with older
  versions the word just does not appear).

## [0.13.0] - 2026-10-25

### Added

- Arrange cards: an edit (pencil) button in the popout header switches to arrange mode
  (the button then shows a check mark). The cards fold up and get a drag handle
  in their title row; drag one within its column or into the other column, a
  line shows the insert position. Outside arrange mode nothing is draggable. Both
  columns stay visible while arranging, so an empty one can take a card. "Reset
  layout" restores the default order. The order is saved per column in the plugin
  settings (`cardOrderLeft`, `cardOrderRight`, lists of card ids); hidden and
  unsupported cards keep their slot, new cards join their default column.

### Changed

- "Hide the bar icon without a camera" no longer polls: the icon follows the
  state of the running `obsbot4linux watch` process (no `obsbot4linux detect`
  every 5 seconds any more), and comes back as soon as the camera is plugged in
  again.

### Fixed

- The "Binding loop detected for property height" warning in the journal when the
  popout opens (title row of the cards).

## [0.12.0] - 2026-10-25

### Added

- Settings page, "Popout cards": one switch per popout card (Preview, Framing,
  Camera, Sleep, Tracking, Picture, Image, Audio, Gestures, Factory reset), all
  on by default. Hidden cards leave the popout only; the bar icon actions and the
  Control Center tile are unaffected, and a card the connected camera does not
  support stays hidden whatever the switch says. The cards below a hidden one move
  up; when a whole column is empty the popout shrinks to the remaining column
  (380 px instead of 760 px). Changes apply at once.
- Settings page, "Status text in the bar" (off by default): "Static" or
  "Tracking" next to the bar icon while the camera is awake, "Asleep" while the
  lens is stowed, "Offline" (dimmed) without a camera. The text sits in a fixed
  slot as wide as the longest text, so the pill never changes width. Horizontal
  bars only; a vertical bar keeps the icon alone. Size and colour follow the bar's
  theme.

## [0.11.1] - 2026-10-25

### Fixed

- The on-air dot shows for every app again, also Chrome (through PipeWire) and
  the widget's own preview: it needs obsbot4linux 0.3.1, which detects
  streaming in the kernel driver instead of by process. Apps it cannot name
  show as "On air" without a name.

## [0.11.0] - 2026-10-25

### Added

- A red on-air dot on the bar icon whenever any application streams from the
  camera, the widget's own preview included (it replaces the white preview dot).
  The tooltip and popout header append "On air: <apps>" (qs shows as "preview",
  Chrome, Firefox and OBS by name), the Control Center tile "On air".
- Requires obsbot4linux 0.3.0 or newer, which reports `streaming` and
  `streaming_apps`; the startup check refuses older versions.

## [0.10.0] - 2026-10-25

### Changed

- The bar icon stays visible while no camera is plugged in, dimmed with usb_off
  (asleep keeps videocam_off, so the two are not confused); a click opens the
  popout with "Camera not connected". The settings page can hide it instead, as
  before ("Hide the bar icon without a camera").

## [0.9.0] - 2026-10-25

### Changed

- The widget no longer assumes a camera model. The name in the popout header,
  the bar tooltip and the Control Center tile, and the video device the
  preview opens, come from obsbot4linux; "OBSBOT camera" is shown until it
  reports a model.
- The bar icon is shown while `obsbot4linux detect` finds a supported camera,
  instead of looking for the Tiny 2 Lite's device file.
- The "Camera not connected" hint no longer names a model.
- Requires obsbot4linux 0.2.0 or newer. The startup check refuses older
  versions and points to the releases page.

## [0.8.0] - 2026-10-25

### Added

- Startup check: the plugin only activates when `obsbot4linux` is on PATH,
  otherwise DMS shows "obsbot4linux is required" with an install hint and the
  releases link. The camera itself is not required.
- Right click on the bar icon wakes or sleeps the camera, the same as the
  Awake switch. Left click still opens the popout.
- Hovering the bar icon shows a tooltip with the camera state, the line from
  the popout header: "Tiny 2 Lite · Awake · Static".
- Mouse wheel on the bar icon zooms by 0.1 per notch (1.0 to 4.0, while the
  camera is awake); middle click switches tracking between Static and the last
  other mode (Normal Tracking until one was used). Both can be switched off on
  the settings page.
- Control Center tile: the icon wakes or sleeps the camera, the subtitle shows
  the state. A 4 × 4 tile shows the tracking modes and speed, the detail page
  the whole Tracking card (also the tracked hand). Control Center runs its own
  instance of the widget, so it starts its own `obsbot4linux watch` while open.

### Changed

- The preview dot on the bar icon also shows in vertical bars.

## [0.7.1] - 2026-10-25

### Changed

- The popout header shows the plugin's name, OBSBOT Control, and puts the
  camera model in front of its state: "Tiny 2 Lite · Awake · Static".

## [0.7.0] - 2026-10-25

### Changed

- Camera access goes through `obsbot4linux` only: one `obsbot4linux watch`
  delivers every state change at once, also changes made from the CLI or by the
  camera itself. `tiny4linux-cli` and `v4l2-ctl` are no longer used.
- The cards are stacked in two independent columns, each as high as its
  content. Collapsible cards start closed, only one is open per column, and a
  closed card lists all its settings under the title.
- Selected chips are marked by colour only, so they keep their width.
- Settings can be changed while the camera sleeps; it applies them when it
  wakes. Only framing, zoom and field of view need it awake.
- The tracked hand (left / right) moved into the Tracking card, greyed out
  outside hand tracking.
- The zoom shows two decimals, so the field of view levels read 1.15× and 1.47×.
- The preview starts from the button in its frame; hovering the running video
  offers to stop it. The switch above the frame is gone.

### Added

- Camera, Sleep, Audio and Gestures cards for the Tiny 2 Lite settings: field
  of view, status LED, mirror, invert, auto-sleep, sleep background, noise
  reduction, pickup distance, automatic gain, microphone while asleep, gesture
  switches and zoom gesture ratio.
- Factory reset with an in-place two-click confirmation.
- Custom (manual) exposure with exposure time and gain.
- Live gimbal pose in the Framing card, also while AI tracking moves it; the
  arrows step from there. Fine steps of 1°.
- The popout scrolls once it outgrows the screen.

### Removed

- Desk and Whiteboard tracking (the Tiny 2 Lite has neither).
- The zone tracking switch, until the zone can be set up from the widget.

### Fixed

- HDR switch, exposure mode and gimbal centring now show and do what the camera
  does.

## [0.6.1] - 2026-10-23

### Changed

- Registry review: theme colours and tokens only, Qt Multimedia optional (the
  preview says so when it is missing), `qt6-multimedia` listed as a dependency.

## [0.6.0] - 2026-10-23

### Added

- First release: OBSBOT Tiny 2 Lite bar widget for DankMaterialShell with
  sleep / wake, AI tracking mode and speed, HDR, exposure, image adjustments,
  gimbal and zoom, and a live preview.
