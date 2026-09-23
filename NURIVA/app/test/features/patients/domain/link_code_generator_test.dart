import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:nuriva/features/patients/domain/link_code_generator.dart';

void main() {
  test('generates a code of the fixed length', () {
    final code = LinkCodeGenerator.generate(random: Random(1));
    expect(code.length, LinkCodeGenerator.length);
    expect(code.length, 6);
  });

  test('never contains characters easy to confuse read aloud or handwritten',
      () {
    // 0/O, 1/I/L are excluded so a code can be dictated over the phone.
    const confusable = {'0', 'O', '1', 'I', 'L'};
    for (var seed = 0; seed < 50; seed++) {
      final code = LinkCodeGenerator.generate(random: Random(seed));
      for (final char in code.split('')) {
        expect(confusable.contains(char), isFalse,
            reason: '"$char" in "$code" (seed $seed) is easy to confuse');
      }
    }
  });

  test('is deterministic for a given seeded Random', () {
    final a = LinkCodeGenerator.generate(random: Random(42));
    final b = LinkCodeGenerator.generate(random: Random(42));
    expect(a, b);
  });

  test('defaults to a secure Random when none is supplied', () {
    // Just verifies it doesn't throw and produces the right shape — the
    // whole point of Random.secure() is that it isn't reproducible.
    final code = LinkCodeGenerator.generate();
    expect(code.length, 6);
  });
}
