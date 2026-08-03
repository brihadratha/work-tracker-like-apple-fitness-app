import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lock screen intents ship in both iOS targets and allow locked use', () {
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    final intents = File(
      'ios/WorkRingsLiveActivity/StopWorkSessionIntent.swift',
    ).readAsStringSync();

    final buildMemberships = RegExp(
      r'StopWorkSessionIntent\.swift in Sources \*/ =',
    ).allMatches(project);
    final sourcePhaseEntries = RegExp(
      r'StopWorkSessionIntent\.swift in Sources \*/,',
    ).allMatches(project);
    expect(buildMemberships.length, 2);
    expect(sourcePhaseEntries.length, 2);

    expect(
      RegExp(
        r'authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed',
      ).allMatches(intents).length,
      2,
    );
    expect('openAppWhenRun: Bool = false'.allMatches(intents).length, 2);
  });

  test('Runner ships the iCloud Documents persistence bridge', () {
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    final entitlements = File(
      'ios/Runner/Runner.entitlements',
    ).readAsStringSync();
    final appDelegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();

    expect(project, contains('ICloudPersistencePlugin.swift in Sources'));
    expect(appDelegate, contains('ICloudPersistencePlugin.register'));
    expect(
      entitlements,
      contains('com.apple.developer.ubiquity-container-identifiers'),
    );
    expect(entitlements, contains('iCloud.ai.atiq.workRings'));
    expect(entitlements, contains('<string>CloudDocuments</string>'));
  });
}
