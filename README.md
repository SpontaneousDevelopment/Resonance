# Resonance

Gamified voice-acting training for iOS, Android and macOS. A single Flutter
codebase, mastery-gated curriculum, scoring on-device.

The full architecture proposal — curriculum, system design, MVP scope and
milestones — is in [`docs/blueprint.html`](docs/blueprint.html).

## Toolchain

Flutter is pinned per-project with [fvm](https://fvm.app) so this repo does not
depend on whatever SDK happens to be on your PATH. The pinned version lives in
`.fvmrc`.

```sh
brew install fvm
fvm install          # fetches the pinned Flutter
fvm flutter pub get  # resolves the whole workspace
```

Always invoke Flutter as `fvm flutter ...` in this repo.

### Platform status

| Target  | Status | Notes |
| ------- | ------ | ----- |
| macOS   | Builds | Primary development target. |
| iOS     | Builds | Requires Xcode; device builds need a signing identity. |
| Android | **Blocked** | Needs a JDK and the Android SDK: `brew install --cask temurin android-studio`, then launch Android Studio once to install the SDK components. |

## Layout

This is a [pub workspace](https://dart.dev/tools/pub/workspaces) — one lockfile
at the root, several packages beneath it.

```
apps/resonance/          the Flutter app
packages/resonance_dsp/  FFI plugin: pitch, RMS, VAD (M1)
packages/resonance_models/  shared models
tools/curriculum_build/  YAML → validated JSON seed
tools/ingest/            licence-checked reference-audio ingestion (M2)
content/curriculum/      the authored curriculum
backend/supabase/        migrations, edge functions, RLS policies
```

Import rules inside the app, in dependency order:

- `domain/` — pure Dart. No Flutter import. Scoring rubrics and the mastery
  ladder live here so they are testable without a binding.
- `core/` — infrastructure. May import `domain/`, never `features/`.
- `features/` — screens and flows. May import anything above.
- `ui/` — the design system. Imported by `features/`, imports nothing from it.

## Common commands

```sh
# Recompile the curriculum after editing content/curriculum/*.yaml.
# Fails the build on a duplicate id, a dangling prerequisite or a cycle.
fvm dart run tools/curriculum_build/bin/build.dart

fvm flutter test                       # from apps/resonance
fvm flutter analyze
fvm flutter run -d macos
```

## Content sourcing

Reference audio comes from sources that permit redistribution, and every clip
carries its provenance through to the UI:

- **Public domain** — LibriVox / Internet Archive recordings.
- **Creative Commons** — YouTube videos whose `license` field reads
  `creativeCommon`, verified via the YouTube Data API before download, with
  attribution retained. `tools/ingest` refuses anything else.
- **Original** — recorded for Resonance.
- **Synthetic** — licensed TTS, always labelled as AI-generated in the UI.
- **Embed** — third-party performances play through the publisher's own
  embedded player and are never downloaded or stored. `content/references/`
  holds video ids and timestamps only.

The build tool enforces the parts of this it can: a `creativeCommons` or
`publicDomain` reference without an `attribution` is a build error.
