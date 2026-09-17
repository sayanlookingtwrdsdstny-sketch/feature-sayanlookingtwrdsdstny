import 'package:flutter_test/flutter_test.dart';
import 'package:nuriva/core/errors/app_failure.dart';
import 'package:nuriva/features/auth/presentation/auth_copy.dart';

void main() {
  const failures = <AppFailure>[
    AppFailure.network(),
    AppFailure.timeout(),
    AppFailure.unauthenticated(),
    AppFailure.permissionDenied(action: 'signIn'),
    AppFailure.permissionDenied(action: 'other'),
    AppFailure.notFound(entity: 'document'),
    AppFailure.validation(field: 'credentials', reason: 'invalid'),
    AppFailure.conflict(reason: 'email_in_use'),
    AppFailure.conflict(reason: 'provider_disabled'),
    AppFailure.conflict(reason: 'unknown'),
    AppFailure.unexpected(),
    AppFailure.rateLimited(),
  ];

  test('every failure produces plain, non-empty copy', () {
    for (final f in failures) {
      final copy = AuthCopy.forFailure(f);
      expect(copy, isNotEmpty, reason: f.code);
      // No error codes or technical tokens leak into the UI.
      expect(copy, isNot(contains('_')), reason: f.code);
      expect(copy.toLowerCase(), isNot(contains('error')), reason: f.code);
      expect(copy.toLowerCase(), isNot(contains('sorry')), reason: f.code);
    }
  });

  test('the credentials message does not reveal whether the account exists',
      () {
    final copy = AuthCopy.forFailure(
      const AppFailure.validation(field: 'credentials', reason: 'invalid'),
    ).toLowerCase();

    expect(copy, isNot(contains('no account')));
    expect(copy, isNot(contains('not found')));
    expect(copy, isNot(contains('not registered')));
  });

  test('field adapter returns null when valid and copy when not', () {
    final validate = AuthCopy.field('email', (v) => v == 'ok' ? null : 'empty');

    expect(validate('ok'), isNull);
    expect(validate(''), 'Enter your email address.');
  });
}
