import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeta_app/services/update_service.dart';

void main() {
  group('UpdateService.isNewerVersion', () {
    test('does not offer an older release as an update', () {
      expect(UpdateService.isNewerVersion('0.1.5', '0.1.6'), isFalse);
    });

    test('offers a newer release as an update', () {
      expect(UpdateService.isNewerVersion('0.1.7', '0.1.6'), isTrue);
    });
  });

  test('uses GitHub as the fallback release endpoint', () {
    expect(
      UpdateService.githubReleasesApi,
      'https://api.github.com/repos/chenflxs/kikoeta/releases/latest',
    );
  });
}
