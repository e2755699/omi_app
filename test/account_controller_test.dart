import 'package:flutter_test/flutter_test.dart';
import 'package:omi_app/data/account_controller.dart';

void main() {
  test('一般開啟網頁不觸發登入回呼', () {
    for (final url in ['http://127.0.0.1:5173/', 'https://example.com/omi_app/#/']) {
      expect(AccountController.isAuthCallbackUri(Uri.parse(url), isWeb: true), isFalse);
    }
  });

  test('Web 辨識 PKCE code 與取消登入的錯誤', () {
    for (final suffix in ['?code=test-code', '?error=access_denied', '#error_description=Cancelled']) {
      expect(AccountController.isAuthCallbackUri(Uri.parse('https://example.com/$suffix'), isWeb: true), isTrue);
    }
  });

  test('手機只接受登入路徑且必須有回呼參數', () {
    expect(AccountController.isAuthCallbackUri(Uri.parse('omiapp://auth-callback?code=test'), isWeb: false), isTrue);
    for (final url in ['omiapp://checkin?code=test', 'other://auth-callback?code=test', 'omiapp://auth-callback']) {
      expect(AccountController.isAuthCallbackUri(Uri.parse(url), isWeb: false), isFalse);
    }
  });

  test('本機返回網址保留 port 並完全移除 ? 與 #', () {
    for (final suffix in ['', '?code=old#fragment', '?#']) {
      expect(AccountController.webRedirectUrl(Uri.parse('http://127.0.0.1:5173/$suffix')), 'http://127.0.0.1:5173/');
    }
  });

  test('GitHub Pages 返回網址保留部署子目錄', () {
    expect(
      AccountController.webRedirectUrl(Uri.parse('https://e2755699.github.io/omi_app/?code=old#/')),
      'https://e2755699.github.io/omi_app/',
    );
  });
}
