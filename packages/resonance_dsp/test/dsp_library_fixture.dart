import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:resonance_dsp/resonance_dsp.dart';

/// Compiles `src/resonance_dsp.c` into a standalone dylib and installs it into
/// the bindings, so unit tests exercise the real shipped C.
///
/// Necessary because `flutter test` runs on the Dart VM, not inside the app
/// binary the podspec links the DSP into — so the usual
/// `DynamicLibrary.process()` lookup finds nothing on macOS and iOS.
///
/// Builds once per test run and caches in the system temp directory.
void loadNativeDspForTesting() {
  if (_loaded) return;

  final packageRoot = _findPackageRoot();
  final source = File('$packageRoot/src/resonance_dsp.c');
  if (!source.existsSync()) {
    throw StateError('Cannot find DSP source at ${source.path}');
  }

  final extension = Platform.isMacOS
      ? 'dylib'
      : (Platform.isWindows ? 'dll' : 'so');
  final output = File(
    '${Directory.systemTemp.path}/resonance_dsp_test.$extension',
  );

  // Rebuild whenever the C is newer than the last build.
  final stale =
      !output.existsSync() ||
      source.statSync().modified.isAfter(output.statSync().modified);

  if (stale) {
    final result = Process.runSync('cc', [
      '-shared',
      '-fPIC',
      '-O2',
      '-I$packageRoot/src',
      source.path,
      '-o',
      output.path,
      '-lm',
    ]);
    if (result.exitCode != 0) {
      throw StateError('Failed to build the DSP for tests:\n${result.stderr}');
    }
  }

  debugOverrideDspLibrary(ffi.DynamicLibrary.open(output.path));
  _loaded = true;
}

bool _loaded = false;

/// Walks up from the test's working directory to the package root.
String _findPackageRoot() {
  var dir = Directory.current;
  while (true) {
    if (File('${dir.path}/pubspec.yaml').existsSync() &&
        Directory('${dir.path}/src').existsSync()) {
      return dir.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('Could not locate the resonance_dsp package root');
    }
    dir = parent;
  }
}
