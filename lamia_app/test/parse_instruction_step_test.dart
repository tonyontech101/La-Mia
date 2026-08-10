// Unit tests for `parseInstructionStep`.
//
// Validates the two branches (colon-delimited title/body, and the generic
// `Step N` fallback) and guards against regressions on edge cases like dotted
// numbers, leading colons, and empty inputs.

import 'package:flutter_test/flutter_test.dart';
import 'package:lamia_app/features/recipes/presentation/recipe_detail_screen.dart';

void main() {
  group('parseInstructionStep', () {
    test('splits "Title: body" into a (title, body) record', () {
      final (title, body) = parseInstructionStep(0, 'Marinate: Mix all ingredients');
      expect(title, 'Marinate');
      expect(body, 'Mix all ingredients');
    });

    test('title and body are trimmed', () {
      final (title, body) =
          parseInstructionStep(0, '   Marinate  :   Mix all ingredients  ');
      expect(title, 'Marinate');
      expect(body, 'Mix all ingredients');
    });

    test('keeps subsequent colons in the body (split joins the remainder)', () {
      final (title, body) = parseInstructionStep(
        0,
        'Sear: Brown the meat. Time: 4-5 minutes',
      );
      expect(title, 'Sear');
      expect(body, 'Brown the meat. Time: 4-5 minutes');
    });

    test('falls back to "Step N" with the raw text when no colon present', () {
      final (title, body) = parseInstructionStep(2, 'Stir until combined');
      expect(title, 'Step 3');
      expect(body, 'Stir until combined');
    });

    test('uses index + 1 for the step number (so first step is "Step 1")', () {
      expect(parseInstructionStep(0, 'a').$1, 'Step 1');
      expect(parseInstructionStep(4, 'a').$1, 'Step 5');
    });

    test('handles empty string as "Step N" with empty body', () {
      final (title, body) = parseInstructionStep(3, '');
      expect(title, 'Step 4');
      expect(body, '');
    });

    test('does not fabricate adobo-specific titles (regression)', () {
      // The previous in-method version returned "Marinate the Chicken" for
      // step 0 of *every* recipe, even leche flan. The current top-level
      // function returns only "Step 1" — no domain-specific defaults.
      final (title, _) = parseInstructionStep(0, 'Whisk yolks and sugar');
      expect(title, 'Step 1');
      expect(title, isNot('Marinate the Chicken'));
    });
  });
}