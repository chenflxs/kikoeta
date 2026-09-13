import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeta_app/services/api_service.dart';

void main() {
  group('ApiService.oneAgeTag', () {
    test('uses one positive tag for a single selected level', () {
      expect(ApiService.oneAgeTag({2}), r'$age:adult$');
      expect(ApiService.oneAgeTag({1}), r'$age:r15$');
      expect(ApiService.oneAgeTag({0}), r'$age:general$');
    });

    test('uses the requested exclusion tag for the R18/R15 combination', () {
      expect(ApiService.oneAgeTag({2, 1}), r'$-age:adult$');
    });

    test('does not add an age tag when none or all levels are selected', () {
      expect(ApiService.oneAgeTag(const <int>{}), isNull);
      expect(ApiService.oneAgeTag({0, 1, 2}), isNull);
    });
  });
}
