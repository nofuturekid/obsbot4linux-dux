# obsbot4linux-dux

Dux (DankMaterialShell) bar widget and desktop preview for OBSBOT webcams, the desktop
frontend of [obsbot4linux](https://github.com/nofuturekid/obsbot4linux). Formerly `dms-obsbot-control`.

![Popout with the preview off](assets/screenshot.png)

## Supported cameras

The widget supports every camera that
[obsbot4linux supports](https://github.com/nofuturekid/obsbot4linux#supported-cameras),
currently the **OBSBOT Tiny 2 Lite**. It takes the camera's name and video device
from obsbot4linux, and shows only the cards the camera can do (its
`capabilities`).

The popout is 920 px wide (at most 90 % of the screen width; the left column takes 55 %, so the preview is larger). The left column is always there: Preview and Framing, so you can
watch the picture while changing settings. The right column is a tab bar with three tabs:
Tracking (Tracking, Zone, Presets), Picture (Picture, Image) and Device (Camera, Sleep, Audio,
Gestures, Factory reset). The tab area is as high as the tallest tab, so the popout does
not jump when switching; the last selected tab is remembered (`lastTab`). Collapsible
cards start closed, one open per tab, and a closed card lists its settings under the title.

**Arrange cards:** the edit (pencil) button in the header switches the popout into arrange
mode (it then reads as a check mark: click it to finish). Cards fold up and show a
handle at the right of the title; drag a card by its handle within its tab, or drop it on
another tab's button to move it to the end of that tab; a line shows where it will land.
Preview and Framing stay in the left column. Nothing can be dragged outside this
mode. "Reset layout" restores the default order. The order is saved per tab as
card ids in `cardTabs` (plugin settings), hidden and unsupported cards keep their
place in it, and cards that are not in the saved list join their default tab at the end.
An order saved by 0.16.0 or older (`cardOrderLeft`, `cardOrderRight`) is migrated: each card
goes to its default tab, ordered by its place in the old column.

- header: OBSBOT Control, the camera model and its state, a spinner while a
  command is in flight, Awake switch
- preview frame (16:9, Qt Multimedia at 720p): live picture while the preview
  runs (no other app can use the camera meanwhile; it stops when the popout
  closes), otherwise a hint with one action: Start preview, Wake camera, or
  Retry when the camera or obsbot4linux can't be reached
- tracking: AI mode, speed (Standard, Headroom with obsbot4linux 0.11, Sport), tracked hand, hand
  return position (return here, go, clear; obsbot4linux 0.6.0), follow new targets (with zone tracking on
  the camera keeps tracking and takes the next person after the target leaves the
  area; obsbot4linux 0.7.3 or later); "searching" in the status while it has lost
  its target; optionally the tracked target's box over the preview (popout and
  desktop widget)
- framing: pan/tilt d-pad with live pose and a 5°/1° step switch, center, zoom beside it; the left and
  right arrows follow the picture (flipped while mirror is on); a manual
  move switches tracking to Static; "Use current pose as start pose" and "Go to start pose"
  (the pose the camera takes at power-on), with the stored start pose shown when obsbot4linux
  reports it
- presets: the camera's three slots with name and pose; Recall, Save current pose, Rename and
  Delete (two-click confirmation); a note while zone tracking follows new targets, because a
  recall makes the next zone return end in Static
- zone: zone tracking on/off, the area (pan and tilt range,
  "Full area"), the return position with "Return here" (current pose) and "Go to return
  position", all read back from the camera. Leaving the area stops tracking (Static, back to the return
  position) unless "Follow new targets" is on, then the camera waits for the next person
- picture: HDR, exposure Global / Face / Custom (exposure time and gain)
- camera: field of view, status LED and LED blink (the camera cannot report it, the switch shows the last value set here), mirror, invert; read-only firmware, anti-flicker, frame rate, digital zoom
- sleep: auto-sleep and the picture while asleep; zoom and tracking mode at power-on, stored in the camera (obsbot4linux 0.10; the camera applies them when it is powered on, not when it wakes from sleep)
- image adjustments: brightness, contrast, saturation, sharpness, backlight
  compensation, reset to defaults
- audio: noise reduction, pickup distance, microphone volume, automatic gain, microphone while asleep
- gestures: gesture switches and zoom ratio
- factory reset with a two-click confirmation
- bar icon: videocam (accent) awake, videocam_off asleep, usb_off dimmed while
  unplugged (or hidden, see settings), a red dot while any application streams from the camera

Bar icon interactions:

| Input        | Action                                                                                 |
| ------------ | -------------------------------------------------------------------------------------- |
| Left click   | Open the popout                                                                        |
| Right click  | Wake / sleep the camera                                                                |
| Middle click | Tracking on/off: Static, and back to the last other mode (Normal Tracking if none yet) |
| Mouse wheel  | Zoom in / out by 0.1 per notch, 1.0 to 4.0, while the camera is awake                  |
| Hover        | Tooltip with the state, e.g. "Tiny 2 Lite · Awake · Static"                            |

On air: a red dot on the bar icon shows whenever an application streams from the
camera (a browser, OBS, ffmpeg, the widget's own preview). The tooltip and the
popout header add "On air: Chrome" and the like, the Control Center tile "On air".
This relies on obsbot4linux's detection of
[streaming applications](https://github.com/nofuturekid/obsbot4linux#streaming-applications),
which looks at processes that map the camera's capture buffers.

Control Center tile: the icon wakes or sleeps the camera, the subtitle shows its
state. A 4 × 4 tile shows the tracking modes and speed; the tile's detail page
also has the tracked hand.

Settings page: a tracking mode applied whenever the camera wakes up, and switches
for "Mouse wheel zooms" and "Middle click toggles tracking" (both on by default).
Right click is always sleep/wake. Further switches, all applied at once:

| Setting                                                                                                                                                         | Key                                                                                                                                                       | Default |
| --------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- | ------- |
| Hide the bar icon without a camera: follows the running watcher, no polling; the icon returns when the camera is plugged in again (off: the icon stays, dimmed) | `hideWithoutCamera`                                                                                                                                       | off     |
| Status text in the bar: Static / Tracking / Asleep / Offline (no camera, dimmed) next to the icon in a fixed-width slot, horizontal bars only                   | `statusTextInBar`                                                                                                                                         | off     |
| Popout cards: Preview, Framing, Camera, Sleep, Tracking, Zone, Presets, Picture, Image, Audio, Gestures, Factory reset                                                   | `cardPreview`, `cardFraming`, `cardCamera`, `cardSleep`, `cardTracking`, `cardZone`, `cardPresets`, `cardPicture`, `cardImage`, `cardAudio`, `cardGestures`, `cardReset` | on      |

The card switches affect the popout only (not the bar icon actions or the Control
Center tile). A card the connected camera does not support stays hidden whatever its
switch says. Hidden cards close up; a tab without cards drops out of the tab bar, and if a whole column
(left, or all tabs) is empty the popout narrows from 920 px to the one column that is left.

## Desktop widget

The plugin also provides a desktop widget: add **OBSBOT Control** in Settings → Desktop
Widgets (it is listed next to the other desktop widgets) and place it like any other. Like the
popout it has one fixed layout, a single card with the controls arranged
around the picture:

- **Picture area** (640 × 360, 16:9, top left): dark with the "Preview is off" hint and a **Start
  preview** button while the preview is off (or Wake camera / Retry when the camera is asleep or not
  reachable); the live picture while it runs, with **Stop preview** on hover. Stopping frees the
  camera.
- **Right of the picture:** status with the camera state (Awake, Asleep, Offline) and the tracking
  mode, a red "On air" dot while another app reads the camera, the tracking mode chips and the
  tracking speed chips.
- **Below the picture:** zoom (slider and − / +) on the left, the presets saved in the camera in the
  middle (empty slots are not shown; a click recalls one) and **Sleep** / **Wake** at the right end
  (**Retry** when the camera is not reachable). Asleep and offline grey the other controls out.

The height follows the bottom row's content and is not saved; the width is fixed. The preview never
starts by itself: while it runs no other app can use the camera, and a small red dot in the
corner shows that.

- The preview keeps running until you close it, the camera goes to sleep or is unplugged,
  or the widget is unloaded (switched off or removed in Desktop Widgets, or the desktop
  is being edited). It does not stop when you merely look elsewhere.
- Only one preview runs at a time: starting it on the desktop switches the popout's
  preview off and the other way round (also for two desktop widgets, e.g. on two screens).
  The bar icon's red dot and "On air: preview" count the desktop preview too.
- The desktop widget runs its own `obsbot4linux watch`, like the Control Center tile.
- While the desktop is being edited the widget is inert (no buttons, no hover).

Camera access goes through [OBSBot4Linux](https://github.com/nofuturekid/obsbot4linux) (`obsbot4linux`):
the widget keeps one `obsbot4linux watch` running, gets every state change as an event
(also changes made from the CLI or by the camera itself) and sends commands on
its stdin. Desk and Whiteboard tracking are not available with obsbot4linux. The bar pill is hidden while no supported
camera is plugged in.

## Install

Needs `obsbot4linux` 0.7.1 or newer on PATH; the plugin checks this when it is
enabled and refuses to activate without it (the camera itself does not have to
be plugged in). Packages for Arch, Debian/Ubuntu, Fedora/openSUSE
and a plain tarball are on its
[releases page](https://github.com/nofuturekid/obsbot4linux/releases). The live preview
also needs `qt6-multimedia`; without it the preview frame says so and every
other control still works.

From the DMS plugin browser, or manually:

```sh
git clone https://github.com/nofuturekid/obsbot4linux-dux.git \
    ~/.config/DankMaterialShell/plugins/obsbot4linuxDux
dms ipc call plugins enable obsbot4linuxDux
```

Then add the `obsbot4linuxDux` widget to a bar in DMS settings.
After changing QML, run `dms restart` (`plugins reload` keeps cached components).

## Update

```sh
dms plugins update obsbot4linuxDux
dms restart
```

## Development

The code was written with Claude Code (AI) and reviewed and tested on a
Tiny 2 Lite.

## License

GPL-3.0-or-later, see [LICENSE](LICENSE).
