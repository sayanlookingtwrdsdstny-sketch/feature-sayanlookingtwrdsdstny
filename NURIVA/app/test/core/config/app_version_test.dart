import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nuriva/core/config/app_version.dart';

void main() {
  test('in-app version matches pubspec.yaml', () {
    // A test APK must never display a version it isn't. The APK's real
    // version comes from pubspec; this keeps the on-screen label honest.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(r'^version:\s*(\S+)', multiLine: true)
        .firstMatch(pubspec);

    expect(match, isNotNull);
    expect(match!.group(1), '${AppVersion.name}+${AppVersion.build}');
  });

  test('module number matches the minor version', () {
    final minor = AppVersion.name.split('.')[1];
    expect(int.parse(AppVersion.module), int.parse(minor));
  });
}
