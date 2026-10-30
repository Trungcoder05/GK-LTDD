part of 'main.dart';

class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  Map<String, dynamic>? user;
  bool loading = true;
  String? error;
  bool sessionExpired = false;

  @override
  void initState() {
    super.initState();
    restoreSession();
  }

  Future<void> restoreSession() async {
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final backgroundedAt = await Api.storage.read(
        key: _backgroundedAtKey,
      );
      await Api.storage.delete(key: _backgroundedAtKey);
      final token = await Api.storage.read(key: 'session_token');
      if (token == null) {
        if (mounted) setState(() => loading = false);
        return;
      }

      final backgroundedAtMillis = int.tryParse(backgroundedAt ?? '');
      if (backgroundedAtMillis != null &&
          DateTime.now()
                  .difference(
                    DateTime.fromMillisecondsSinceEpoch(backgroundedAtMillis),
                  ) >=
              sessionTimeout) {
        await api.logout();
        if (mounted) {
          setState(() {
            sessionExpired = true;
            loading = false;
          });
        }
        return;
      }

      api.token = token;
      final restoredUser = Map<String, dynamic>.from(
        await api.call('GET', '/me'),
      );
      final email = restoredUser['email']?.toString();
      if (email != null && email.isNotEmpty) {
        await Api.storage.write(key: 'remembered_account', value: email);
      }
      final savedUserId = await Api.storage.read(key: 'session_user_id');
      if (savedUserId != null && savedUserId != restoredUser['id']) {
        await api.logout();
        if (mounted) setState(() => loading = false);
        return;
      }
      if (mounted) {
        setState(() {
          user = restoredUser;
          loading = false;
        });
      }
    } on ApiException catch (e) {
      api.token = null;
      if (e.statusCode == 401) {
        await Api.storage.delete(key: 'session_token');
        await Api.storage.delete(key: 'session_user_id');
        if (mounted) setState(() => loading = false);
      } else if (mounted) {
        setState(() {
          error = e.message;
          loading = false;
        });
      }
    } catch (e) {
      api.token = null;
      if (mounted) {
        setState(() {
          error = e.toString();
          loading = false;
        });
      }
    }
  }

  Future<void> goToLogin() async {
    await api.logout();
    if (mounted) setState(() => user = null);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (user case final restoredUser?) {
      return Home(user: restoredUser);
    }
    if (error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Không thể khôi phục phiên: $error'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: restoreSession,
                  child: const Text('Thử lại'),
                ),
                TextButton(
                  onPressed: goToLogin,
                  child: const Text('Đăng nhập lại'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Login(sessionExpired: sessionExpired);
  }
}

class Login extends StatefulWidget {
  final bool sessionExpired;

  const Login({super.key, this.sessionExpired = false});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final username = TextEditingController(),
      password = TextEditingController(),
      email = TextEditingController(),
      name = TextEditingController(),
      code = TextEditingController();
  bool register = false, busy = false, hasBiometricSession = false;
  String? challenge;

  @override
  void initState() {
    super.initState();
    loadRememberedAccount();
  }

  Future<void> loadRememberedAccount() async {
    final values = await Future.wait([
      Api.storage.read(key: 'remembered_account'),
      Api.storage.read(key: 'biometric_token'),
    ]);
    if (!mounted) return;
    setState(() {
      if (username.text.isEmpty && values[0] != null) {
        username.text = values[0]!;
      }
      hasBiometricSession = values[1] != null;
    });
  }

  @override
  void dispose() {
    for (final c in [username, password, email, name, code]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> work(Future<void> Function() fn) async {
    setState(() => busy = true);
    try {
      await fn();
    } catch (e) {
      if (mounted) notify(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> enter(
    Map<String, dynamic> result, {
    String? rememberedAccount,
  }) async {
    final user = Map<String, dynamic>.from(result['user']);
    final biometricToken = await Api.storage.read(key: 'biometric_token');
    if (biometricToken != null) {
      final biometricUserId = await Api.storage.read(key: 'biometric_user_id');
      if (biometricUserId != user['id']) {
        await Api.clearBiometricSession();
      }
    }
    final token = result['token']?.toString();
    if (token == null || token.isEmpty) {
      throw Exception('Máy chủ không trả về phiên đăng nhập hợp lệ.');
    }
    await Api.storage.write(key: 'session_token', value: token);
    await Api.storage.write(
      key: 'session_user_id',
      value: user['id'].toString(),
    );
    final account =
        rememberedAccount?.trim().isNotEmpty == true
        ? rememberedAccount!.trim()
        : user['email']?.toString();
    if (account != null && account.isNotEmpty) {
      await Api.storage.write(key: 'remembered_account', value: account);
    }
    await Api.storage.delete(key: _backgroundedAtKey);
    api.token = token;
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => Home(user: user)));
  }

  Future<void> submit() => work(() async {
    if (challenge != null) {
      await enter(
        Map<String, dynamic>.from(
          await api.call('POST', '/auth/otp', {
            'challengeId': challenge,
            'code': code.text.trim(),
          }),
        ),
        rememberedAccount: register ? email.text : username.text,
      );
      return;
    }
    final path = register
        ? '/auth/register'
        : password.text.isEmpty
        ? '/auth/login/otp'
        : '/auth/login';
    final r = await api.call('POST', path, {
      'username': username.text.trim(),
      if (register || password.text.isNotEmpty) 'password': password.text,
      if (register) 'email': email.text.trim(),
      if (register) 'name': name.text.trim(),
    });
    setState(() => challenge = r['challengeId']);
    if (mounted) notify(context, r['message']);
  });
  Future<void> biometric() => work(() async {
    final auth = FingerprintAuth();
    if (!mounted) return;
    final savedMethod = await Api.storage.read(key: 'biometric_method');
    final savedBiometricType = switch (savedMethod) {
      'face' => BiometricType.face,
      'fingerprint' => BiometricType.fingerprint,
      'strong' => BiometricType.strong,
      'weak' => BiometricType.weak,
      _ => null,
    };
    final availableMethods = await auth.availableMethods();
    if (!mounted) return;
    final method =
        savedBiometricType != null &&
            availableMethods.contains(savedBiometricType)
        ? savedBiometricType
        : await auth.chooseMethod(context);
    if (!mounted) return;
    if (!await auth.authenticate(context, method)) return;
    final token = await Api.storage.read(key: 'biometric_token');
    if (token == null) {
      throw Exception(
        'Hãy đăng nhập bằng OTP và bật sinh trắc học trong cài đặt tài khoản trước.',
      );
    }
    await Api.storage.write(
      key: 'biometric_method',
      value: auth.methodKey(method),
    );
    api.token = token;
    try {
      final user = Map<String, dynamic>.from(await api.call('GET', '/me'));
      final biometricUserId = await Api.storage.read(key: 'biometric_user_id');
      if (biometricUserId != null && biometricUserId != user['id']) {
        await Api.clearBiometricSession();
        throw Exception('Phiên sinh trắc học không khớp tài khoản.');
      }
      if (biometricUserId == null) {
        await Api.storage.write(key: 'biometric_user_id', value: user['id']);
      }
      await enter({'token': token, 'user': user});
    } catch (e) {
      await api.logout();
      rethrow;
    }
  });
  Future<void> google() => work(() async {
    if (!api.configured) throw Exception('Cần cấu hình địa chỉ backend trước.');
    final verifier = base64UrlEncode(
      List<int>.generate(32, (_) => Random.secure().nextInt(256)),
    );
    final digest = sha256.convert(utf8.encode(verifier)).toString();
    final result = await FlutterWebAuth2.authenticate(
      url: '${Api.base}/auth/google/start?verifierHash=$digest',
      callbackUrlScheme: 'childguard',
    );
    final callback = Uri.parse(result);
    final error = callback.queryParameters['error'];
    if (error != null) throw Exception(error);
    final c = callback.queryParameters['code'];
    if (c == null) throw Exception('Google chưa trả mã xác thực');
    final response = Map<String, dynamic>.from(
      await api.call('POST', '/auth/google/exchange', {
        'code': c,
        'verifier': verifier,
      }),
    );
    if (response['requiresOtp'] == true) {
      if (!mounted) return;
      setState(() {
        challenge = response['challengeId'];
        code.clear();
      });
      notify(context, response['message']);
      return;
    }
    final user = response['user'];
    await enter(
      response,
      rememberedAccount: user is Map<String, dynamic>
          ? user['email']?.toString()
          : null,
    );
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(26, 26, 26, 36),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE7EFE3),
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(42),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const BrandMark(size: 46),
                            const SizedBox(width: 12),
                            const Text(
                              'An Tâm Số',
                              style: TextStyle(
                                color: ink,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.6,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    challenge != null
                                        ? 'Xác nhận\nlà bạn nhé'
                                        : register
                                        ? 'Bắt đầu từ\nmột kết nối tốt'
                                        : 'Lớn lên an toàn,\nbên nhau mỗi ngày',
                                    style: const TextStyle(
                                      color: ink,
                                      fontSize: 29,
                                      height: 1.12,
                                      letterSpacing: -0.8,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'Một không gian số dịu dàng cho cả gia đình.',
                                    style: TextStyle(
                                      color: Color(0xFF627166),
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              width: 88,
                              height: 100,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF4E7),
                                borderRadius: BorderRadius.circular(44),
                              ),
                              child: const Stack(
                                alignment: Alignment.center,
                                children: [
                                  Icon(
                                    Icons.phone_iphone_rounded,
                                    color: green,
                                    size: 46,
                                  ),
                                  Positioned(
                                    right: 12,
                                    top: 16,
                                    child: Icon(
                                      Icons.auto_awesome_rounded,
                                      color: coral,
                                      size: 22,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          challenge != null
                              ? 'Nhập mã OTP'
                              : register
                              ? 'Tạo tài khoản gia đình'
                              : 'Chào mừng bạn trở lại',
                          style: TextStyle(
                            fontSize: 22,
                            letterSpacing: -0.3,
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          challenge != null
                              ? 'Mã được gửi đến email và có hiệu lực trong 5 phút.'
                              : register
                              ? 'Đăng ký bằng email để lưu hồ sơ gia đình.'
                              : 'Đăng nhập để tiếp tục chăm sóc nếp sống số.',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            height: 1.45,
                          ),
                        ),
                        if (widget.sessionExpired) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'Phiên đã khóa vì bạn rời ứng dụng quá 30 giây. Đăng nhập lại bằng email/OTP hoặc sinh trắc học.',
                          ),
                        ],
                        const SizedBox(height: 22),
                        if (!api.configured)
                          Container(
                            padding: const EdgeInsets.all(14),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF1E8),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Text(
                              'Chưa cấu hình máy chủ. Xem hướng dẫn chạy backend để kết nối.',
                              style: TextStyle(color: Color(0xFF9A4E13)),
                            ),
                          ),
                        if (challenge != null) ...[
                          field(
                            code,
                            'Mã OTP 6 chữ số',
                            keyboard: TextInputType.number,
                          ),
                        ] else ...[
                          if (register) ...[
                            field(name, 'Họ tên'),
                            field(
                              email,
                              'Địa chỉ email',
                              keyboard: TextInputType.emailAddress,
                            ),
                          ],
                          field(
                            username,
                            register
                                ? 'Tên đăng nhập (3–32 ký tự)'
                                : 'Tên đăng nhập hoặc email',
                          ),
                          field(
                            password,
                            register
                                ? 'Mật khẩu (ít nhất 10 ký tự)'
                                : 'Mật khẩu (để trống để nhận OTP)',
                            secret: true,
                          ),
                        ],
                        SizedBox(
                          height: 54,
                          child: FilledButton(
                            onPressed: busy ? null : submit,
                            child: Text(
                              busy
                                  ? 'Đang xử lý…'
                                  : challenge != null
                                  ? 'Xác thực & tiếp tục'
                                  : register
                                  ? 'Tạo tài khoản'
                                  : 'Đăng nhập với OTP',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        if (challenge == null) ...[
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              const Expanded(child: Divider()),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Text(
                                  'HOẶC',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: const Color(0xFF8A938B),
                                        letterSpacing: 1.3,
                                      ),
                                ),
                              ),
                              const Expanded(child: Divider()),
                            ],
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: busy ? null : google,
                            icon: const Icon(Icons.g_mobiledata_rounded),
                            label: const Text('Tiếp tục với Google'),
                          ),
                          if (hasBiometricSession)
                            TextButton.icon(
                              onPressed: busy ? null : biometric,
                              icon: const Icon(Icons.face_retouching_natural),
                              label: const Text(
                                'Mở phiên bằng khuôn mặt / vân tay',
                              ),
                            ),
                        ],
                        Align(
                          child: TextButton(
                            onPressed: busy
                                ? null
                                : () => setState(() {
                                    challenge = null;
                                    register = !register;
                                    code.clear();
                                  }),
                            child: Text(
                              challenge != null
                                  ? 'Quay lại / gửi mã mới'
                                  : register
                                  ? 'Đã có tài khoản? Đăng nhập'
                                  : 'Chưa có tài khoản? Đăng ký',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
