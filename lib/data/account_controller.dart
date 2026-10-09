import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 登入與本機打卡分開：沒有雲端設定或登入失敗，也不影響本機使用。
class AccountController extends ChangeNotifier {
  AccountController.local() : _client = null;

  AccountController._(this._client) {
    _subscription = _client!.auth.onAuthStateChange.listen(
      (_) => notifyListeners(),
      onError: (Object error) {
        _message = '登入沒有完成，可以再試一次，或先在本機使用。';
        notifyListeners();
      },
    );
  }

  static const redirectUrl = 'omiapp://auth-callback';

  static Future<AccountController> initialize() async {
    const url = String.fromEnvironment('SUPABASE_URL');
    const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
    if (url.isEmpty || key.isEmpty) return AccountController.local();
    try {
      final supabase = await Supabase.initialize(
        url: url,
        publishableKey: key,
        debug: false,
        authOptions: FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
          detectSessionInUriPredicate: (uri) => kIsWeb || (uri.scheme == 'omiapp' && uri.host == 'auth-callback'),
        ),
      );
      return AccountController._(supabase.client);
    } catch (_) {
      return AccountController.local().._message = '目前無法連接登入服務，你仍然可以在本機使用。';
    }
  }

  final SupabaseClient? _client;
  StreamSubscription<AuthState>? _subscription;
  bool _busy = false;
  String? _message;

  bool get configured => _client != null;
  SupabaseClient? get client => _client;
  String? get userId => _client?.auth.currentUser?.id;
  bool get isSignedIn => _client?.auth.currentUser != null;
  bool get busy => _busy;
  String? get message => _message;

  Future<void> signInWithDiscord() async {
    if (_busy || _client == null) return;
    _busy = true;
    _message = null;
    notifyListeners();
    try {
      final launched = await _client.auth.signInWithOAuth(
        OAuthProvider.discord,
        redirectTo: kIsWeb ? Uri.base.replace(query: '', fragment: '').toString() : redirectUrl,
      );
      _message = launched ? '完成 Discord 登入後，回來繼續。' : '無法開啟登入頁，請再試一次。';
    } catch (_) {
      _message = '登入沒有完成，可以再試一次，或先在本機使用。';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    if (_busy || _client == null) return;
    _busy = true;
    notifyListeners();
    try {
      await _client.auth.signOut(scope: SignOutScope.local);
      _message = null;
    } catch (_) {
      _message = '登出沒有完成，請再試一次。';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
