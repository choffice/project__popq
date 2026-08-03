import 'package:naver_login_sdk/naver_login_sdk.dart';

class NaverAuthService {
  Future<String> signInAndGetAccessToken() async {
    final isLoggedIn = await NaverLoginSDK.login();

    if (!isLoggedIn) {
      throw StateError('네이버 로그인에 실패했습니다.');
    }

    final accessToken = await NaverLoginSDK.getAccessToken();

    if (accessToken.isEmpty) {
      throw StateError('네이버 Access Token을 받지 못했습니다.');
    }

    return accessToken;
  }

  Future<void> signOut() async {
    await NaverLoginSDK.logout();
  }

  Future<void> disconnect() async {
    await NaverLoginSDK.logout(isForced: true);
  }
}