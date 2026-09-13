import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeta_app/widgets.dart';

void main() {
  test('shows all advanced parameters after a dollar sign', () {
    final suggestions = advancedSearchParameterSuggestions(r'$');

    expect(suggestions, isNotEmpty);
    expect(suggestions.first.token, r'$tag:');
  });

  test('narrows suggestions to the current parameter prefix', () {
    final suggestions = advancedSearchParameterSuggestions(r'作品 $-a');

    expect(suggestions.map((item) => item.token), contains(r'$-age:'));
    expect(suggestions.every((item) => item.token.startsWith(r'$-a')), isTrue);
  });

  test('does not suggest parameters in an ordinary search word', () {
    expect(advancedSearchParameterSuggestions('作品名'), isEmpty);
  });
}
