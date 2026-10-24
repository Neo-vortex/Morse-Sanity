# Morse Sanity

A Flutter app for learning Morse code: a level-based course for receiving and
sending, seven emulated telegraph keys, and every feature unlocked. It works
fully offline and has no ads or in-app purchases.

## Features

**Course: 110 receive levels + 110 send levels**
- Letters (starting with E and T), numbers, punctuation, prosigns, Q-codes,
  abbreviations, words (short to very long, picked at random each time),
  callsigns and sentences.
- Review levels and timed **challenge levels** with no hints. You can retry
  challenges as often as you like.
- 1–3 stars per level (70 / 80 / 90 %). Passing a level unlocks the next one,
  or turn on *Unlock all levels* in settings.
- Three-step hints: show the code, show the code on every keyboard key, then
  show the answer.
- On-screen answer keyboard in QWERTY, QWERTZ, AZERTY, alphabetical, Dvorak,
  Colemak or Workman layouts, or randomised for every level.

**Sending keys**: straight key, dit/dah buttons, sideswiper (cootie), bug,
single-lever paddle, iambic mode A and iambic mode B, with a swap option for
left-handed operators. On a hardware keyboard, use space or the ←/→ (or `[`/`]`) keys.

**Output modes**: sound, on-screen blinking light, camera flashlight and
vibration, in any combination. You can also set background noise.

**Settings**: words per minute (5–50), Farnsworth speed, tone pitch, volume,
noise level and interface sounds.

**Also included**
- Custom challenge builder: choose the content mix, the number of rounds, a
  time limit per item and an override speed.
- Koch-method lessons, quick recognition drills, word copying and free keying.
- Text ↔ Morse translator with playback.
- Reference chart of characters, prosigns, Q-codes and abbreviations, with meanings.
- Statistics: course progress and per-character accuracy for receiving and
  sending.

## Building

```sh
flutter pub get
flutter test
flutter build apk --release   # local builds are signed with the debug key
```

## Releases

[`.github/workflows/release.yml`](.github/workflows/release.yml) analyzes,
tests and builds the APK on GitHub Actions, signs it, and attaches it to a
GitHub Release:

- every push to `main` publishes a **pre-release** tagged `v<version>-build.<run>`
- pushing a tag such as `v1.2.0` publishes a **full release**

CI signs with a **throwaway test key** that it generates on every run. No real
key is stored anywhere. Because each build has a different signature, Android
won't install one build over another, so uninstall the old version first. For
store releases or seamless updates, create a real keystore and point
`android/key.properties` (gitignored) at it:

```properties
storeFile=/absolute/path/to/release.jks
storePassword=...
keyAlias=...
keyPassword=...
```
