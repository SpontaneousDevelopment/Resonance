import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/telemetry/local_funnel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late LocalFunnel funnel;
  late StreamController<AuthState> auth;
  late FunnelRecorder recorder;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    funnel = LocalFunnel(SharedPreferences.getInstance);
    auth = StreamController<AuthState>.broadcast();
    recorder = FunnelRecorder(funnel: funnel, authChanges: auth.stream);
  });

  tearDown(() async {
    recorder.dispose();
    await auth.close();
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('starting stamps the first launch', () async {
    recorder.start();
    await settle();

    final snapshot = await funnel.read();
    expect(snapshot.firstLaunch, isNotNull);
    expect(snapshot.firstSignIn, isNull, reason: 'nobody has signed in yet');
  });

  test(
    'signing in is recorded, which is the whole point of the recorder',
    () async {
      recorder.start();
      await settle();

      auth.add(AuthState(AuthChangeEvent.signedIn, null));
      await settle();

      final snapshot = await funnel.read();
      expect(
        snapshot.firstSignIn,
        isNotNull,
        reason: 'the conversion event was not written down',
      );
      expect(snapshot.timeToConvert, isNotNull);
    },
  );

  test('a later sign-in does not overwrite the first', () async {
    recorder.start();
    await settle();

    auth.add(AuthState(AuthChangeEvent.signedIn, null));
    await settle();
    final first = (await funnel.read()).firstSignIn;

    await Future<void>.delayed(const Duration(milliseconds: 5));
    auth.add(AuthState(AuthChangeEvent.signedIn, null));
    await settle();

    expect(
      (await funnel.read()).firstSignIn,
      first,
      reason: 'a return visit is not a conversion',
    );
  });

  test('other auth events are not conversions', () async {
    recorder.start();
    await settle();

    auth.add(AuthState(AuthChangeEvent.tokenRefreshed, null));
    auth.add(AuthState(AuthChangeEvent.signedOut, null));
    await settle();

    expect((await funnel.read()).firstSignIn, isNull);
  });

  test('disposing actually stops it listening', () async {
    recorder.start();
    await settle();
    recorder.dispose();

    auth.add(AuthState(AuthChangeEvent.signedIn, null));
    await settle();

    expect(
      (await funnel.read()).firstSignIn,
      isNull,
      reason: 'a disposed recorder kept writing',
    );
  });
}
