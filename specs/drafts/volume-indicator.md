# Showing the volume the bell will ring at

Implements [#2](https://github.com/skagedal/jikido/issues/2).

A sitting's bell should be as loud as it was yesterday. Too quiet and the
closing bell is missed, which is the one thing Jikido exists to prevent;
too loud and the opening bell is a jolt. But the phone's volume drifts
between sittings — a podcast, a call, a video in bed — and nothing on
screen says where it has got to. The first you hear of it is the opening
bell.

Jikido cannot set the volume on iOS, and should not set it on Android
either: the buttons on the side of the phone are the control people
already know. What it can do is show the level, live, before the sitting
starts.

## Functionality

### Which volume

The volume that matters is the one the bell plays at, and that differs
between the platforms because of how Jikido plays it.

On **Android** the bell uses the alarm usage, so it plays at the *alarm*
volume, not the media volume. The indicator shows the alarm volume.
Jikido also makes the volume buttons adjust the alarm volume while it is
in the foreground. Today they adjust media volume, which means a person
turning the phone up before a sitting moves a slider that has nothing to
do with the bell — the indicator would show them that, but it is better
not to set the trap at all.

On **iOS** there is one output volume for playback, and the bell's audio
session ignores the ring/silent switch, so the indicator shows the output
volume and nothing else. It is the volume of whatever the sound is going
to: with AirPods connected it is their level, which is correct, since
that is where the bell will ring.

### Where it is shown

On the home screen, while no sitting is running, in the top left corner.
And during the settling time, in the same place,
because that is when someone who has just pressed Sit notices the phone
is on silent-ish and reaches for the buttons. Once the opening bell has
rung it goes — nothing on screen during a sitting should ask to be looked
at, and the opening bell has by then answered the question more directly
than a number can.

On the bell page too, in the top right corner, since striking the bell on its
own is exactly how someone checks how loud it is.

It is not in the notification shade and not on the completion screen.

### What it looks like

Just the number: **50%**, small, in the faded grey the other quiet
controls use. At zero it is vermilion, since then the bell will not be
heard.

It changes live when the volume buttons are pressed, without a tap or a
redraw of anything else.

### When the level cannot be read

If the platform will not say — an emulator, a simulator, a platform
channel that throws — the indicator is not shown at all. A number stuck at
zero or at some default would be a confident wrong answer, which is worse
than no answer, and the rest of the app is unaffected.

## Implementation

### A platform channel of our own

The obvious dependency is `flutter_volume_controller`, and it is not
used. On iOS it sets volume through `MPVolumeView` and exposes
`setIOSAudioSessionCategory`, so it has audio session handling of its
own; Jikido's audio session category and
options are set deliberately in `bell_audio.dart`, and a second party
able to touch them is a risk to the one guarantee the app makes. What is
needed is a read and a change notification, which is a few dozen lines
per platform. Owning them costs less than auditing a plugin's session
handling across its upgrades.

A method channel, `jikido/volume`, and an event channel,
`jikido/volume/changes`. They cannot share a name: an event channel
listens through a method channel of its own name, and the two handlers
would replace each other on the platform side.

- `get` returns a map: `level`, the current level as a `double` from 0.0
  to 1.0, and `steps`, the number of steps on that platform, as an `int`.
- The event channel emits the same map whenever the level changes.

**iOS** (`ios/Runner/VolumeChannel.swift`, registered from
`didInitializeImplicitFlutterEngine` in `AppDelegate.swift` through
`engineBridge.pluginRegistry.registrar(forPlugin: "VolumeChannel")`):
`AVAudioSession.sharedInstance().outputVolume` for `get`, and key-value
observation of `outputVolume` for events. It reads the shared session and
never sets its category or activates it. `steps` is 16.

`outputVolume` only updates while the session is active, and
`audio_session` does not make it so at startup: it configures the session,
and just_audio activates it on the first `play()`. Until something has
played — the keep-alive, a sitting's bell, the free-play bell — the
reading may be stale and no change is reported. Activating it here instead
would duck whatever else is playing the moment Jikido opens, because the
session's options say to. See "Open questions".

**Android** (`android/app/src/main/kotlin/tech/skagedal/jikido/VolumeChannel.kt`,
registered in `MainActivity.configureFlutterEngine`):
`AudioManager.getStreamVolume(STREAM_ALARM)` divided by
`getStreamMaxVolume(STREAM_ALARM)`, and a `ContentObserver` on
`Settings.System.CONTENT_URI` for events, re-reading the alarm stream on
each change and emitting only when it moved. `steps` is the max volume.
`MainActivity.onCreate` also sets `volumeControlStream =
AudioManager.STREAM_ALARM`, which is what makes the side buttons adjust
the alarm volume while Jikido is in front.

### Dart

- `lib/src/volume.dart` — `VolumeLevel { double level; int steps; }` and
  an abstract `Volume` with `Future<VolumeLevel?> read()` and
  `Stream<VolumeLevel> get changes`. `PlatformVolume` implements it over
  the channels, returning `null` from `read` and an empty stream when the
  channel throws `MissingPluginException` or `PlatformException`, or
  answers with something that is not the map.
- `lib/src/sitting_controller.dart` — takes a `Volume` by injection like
  its other layers, defaulting to `PlatformVolume()`. It exposes `volume` (the latest `VolumeLevel?`) and listens to
  `changes` from `initialize` until `dispose`, calling `notifyListeners`
  on each. It also reads the level again in `onResumed`, since neither
  platform reports a change made while the app was in the background.
- `lib/src/ui/volume_indicator.dart` — the widget, taking the current
  `VolumeLevel?` and rendering nothing for null.
- `lib/src/ui/sitting_page.dart` — the indicator as the app bar's
  `leading` when idle and while `isPreparing`.
- `lib/src/ui/bell_page.dart` — the indicator in the app bar's `actions`.

`test/fakes.dart` gains `FakeVolume`, with a settable level and a
`StreamController` for changes. Tests cover: the controller
passes changes through and reads again on resume; `PlatformVolume` over a
mocked channel; the indicator's percentage, vermilion at zero;
nothing rendered when the level is unreadable; and the indicator on the
home screen and through the settling time, gone at the opening bell, and
on the bell page.

### Documentation

`README.md` gains a paragraph at the end of "Making sure the bell
is heard", on the indicator and on the volume buttons adjusting the
alarm volume on Android.

## Open questions

- **Whether iOS reports the right level before anything has played.**
  See the iOS section. There are also reports of `outputVolume` coming
  back stale after reactivating a session on iOS 18
  ([Apple forums](https://developer.apple.com/forums/thread/799104)). This
  needs trying on the phone: open Jikido cold, change the volume with the
  buttons, and see whether the number moves before the bell has been struck.
  If it does not, the choices are activating the session early after all,
  or not showing the indicator on iOS until the session is known to be
  active.

- **Showing it during the sitting.** Hiding it after the opening bell
  follows the rule that nothing on screen during a sitting asks for
  attention. But a volume turned down mid-sitting by a pocket is exactly
  the failure it would catch. A warning that only appears at zero, during
  a sitting, might be worth the exception.
- **Taking over the volume buttons on Android.** Pointing them at the
  alarm stream is right for Jikido in the foreground, but a person who
  opens Jikido while listening to something will find the buttons no
  longer turn that down. Limiting it to the home screen and the settling
  time, rather than the whole activity, is the alternative.
- **The plugin after all.** If `flutter_volume_controller` turns out to
  read iOS volume without touching the session — its source would settle
  it — the platform code here could be dropped in favour of it.
