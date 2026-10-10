import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// 登入與本機打卡分開：沒有雲端設定或登入失敗，也不影響本機使用。
class AccountController extends ChangeNotifier {
  AccountController.local() : _client = null;

  AccountController._(this._client) {
    _subscription = _client!.auth.onAuthStateChange.listen(
      (state) {
        // Drop the "come back after login" hint once the session arrives.
        if (state.event == AuthChangeEvent.signedIn) _message = null;
        notifyListeners();
      },
      onError: (Object error) {
        _message = '這次沒登入成功，再試一次看看？不急的話，也可以先自己走。';
        notifyListeners();
      },
    );
  }

  static const redirectUrl = 'omiapp://auth-callback';
  static const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const offlineMessage = '好像還沒連上網路呢 📡\n連上之後再來找夥伴吧，你的紀錄都好好收著。';

  /// Building the OAuth URL needs no network, so without this check an offline
  /// tap opens the browser straight onto an error page.
  static Future<bool> _online() async {
    try {
      // Any HTTP status (even 401) proves the auth server is reachable.
      await http.get(Uri.parse('$_supabaseUrl/auth/v1/health')).timeout(const Duration(seconds: 5));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 只處理真正的登入回呼，避免一般開啟網頁也被當成登入失敗。
  static bool isAuthCallbackUri(Uri uri, {required bool isWeb}) {
    if (!isWeb && (uri.scheme != 'omiapp' || uri.host != 'auth-callback')) return false;
    try {
      final fragment = Uri.splitQueryString(uri.fragment);
      return const [
        'code',
        'error',
        'error_code',
        'error_description',
      ].any((key) => uri.queryParameters.containsKey(key) || fragment.containsKey(key));
    } on FormatException {
      return false;
    }
  }

  /// 重建網址以移除 query 與 fragment，不能留下空的 ?#，否則不符 allow list。
  static String webRedirectUrl(Uri uri) =>
      Uri(scheme: uri.scheme, host: uri.host, port: uri.hasPort ? uri.port : null, path: uri.path).toString();

  static Future<AccountController> initialize() async {
    const url = _supabaseUrl;
    const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
    if (url.isEmpty || key.isEmpty) return AccountController.local();
    try {
      final supabase = await Supabase.initialize(
        url: url,
        publishableKey: key,
        debug: false,
        authOptions: FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
          detectSessionInUriPredicate: (uri) => isAuthCallbackUri(uri, isWeb: kIsWeb),
        ),
      );
      return AccountController._(supabase.client);
    } catch (_) {
      return AccountController.local().._message = '現在連不上登入服務，先自己走走，紀錄都會留在這台裝置。';
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
      if (!await _online()) {
        _message = offlineMessage;
      } else if (kIsWeb) {
        final launched = await _client.auth.signInWithOAuth(OAuthProvider.discord, redirectTo: webRedirectUrl(Uri.base));
        _message = launched ? '在 Discord 按下授權，就會回到這裡。' : '無法開啟登入頁，請再試一次。';
      } else {
        // System auth session (ASWebAuthenticationSession / Custom Tabs) receives the callback and closes itself.
        final auth = await _client.auth.getOAuthSignInUrl(provider: OAuthProvider.discord, redirectTo: redirectUrl);
        final callback = await FlutterWebAuth2.authenticate(url: auth.url, callbackUrlScheme: 'omiapp');
        await _client.auth.getSessionFromUrl(Uri.parse(callback));
      }
    } on PlatformException catch (e) {
      // CANCELED = user closed the login sheet; not an error.
      if (e.code != 'CANCELED') _message = '這次沒登入成功，再試一次看看？不急的話，也可以先自己走。';
    } catch (_) {
      _message = '這次沒登入成功，再試一次看看？不急的話，也可以先自己走。';
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
