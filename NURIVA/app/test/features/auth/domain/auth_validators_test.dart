import 'package:flutter_test/flutter_test.dart';
import 'package:nuriva/features/auth/domain/auth_validators.dart';

void main() {
  group('email', () {
    test('accepts ordinary addresses', () {
      for (final e in ['a@b.co', 'asha.rao@example.com', '  x@y.in  ']) {
        expect(AuthValidators.email(e), isNull, reason: e);
      }
    });

    test('reports empty', () {
      expect(AuthValidators.email(''), 'empty');
      expect(AuthValidators.email('   '), 'empty');
      expect(AuthValidators.email(null), 'empty');
    });

    test('reports malformed addresses', () {
      for (final e in ['asha', 'asha@', '@example.com', 'a@b', 'a b@c.d']) {
        expect(AuthValidators.email(e), 'invalid', reason: e);
      }
    });
  });

  group('password', () {
    test('requires 8 characters and nothing more', () {
      expect(AuthValidators.password('12345678'), isNull);
      expect(AuthValidators.password('abcdefgh'), isNull);
      expect(AuthValidators.password('1234567'), 'too_short');
      expect(AuthValidators.password(''), 'empty');
      expect(AuthValidators.password(null), 'empty');
    });
  });

  group('displayName', () {
    test('accepts a trimmed, non-empty name up to 60 characters', () {
      expect(AuthValidators.displayName('Asha'), isNull);
      expect(AuthValidators.displayName('a' * 60), isNull);
    });

    test('rejects empty and over-long names', () {
      expect(AuthValidators.displayName('   '), 'empty');
      expect(AuthValidators.displayName('a' * 61), 'too_long');
    });
  });

  test('normalizeEmail trims and lower-cases', () {
    expect(AuthValidators.normalizeEmail('  Asha@Example.COM '),
        'asha@example.com');
  });
}
