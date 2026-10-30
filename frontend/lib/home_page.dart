part of 'main.dart';

class _ProfileEditDialog extends StatefulWidget {
  final String initialName;

  const _ProfileEditDialog({required this.initialName});

  @override
  State<_ProfileEditDialog> createState() => _ProfileEditDialogState();
}

class _ProfileEditDialogState extends State<_ProfileEditDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialName;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Cập nhật hồ sơ'),
    content: Form(
      key: _formKey,
      child: TextFormField(
        controller: _controller,
        autofocus: true,
        maxLength: 80,
        decoration: const InputDecoration(labelText: 'Tên hiển thị'),
        validator: (value) {
          final name = value?.trim() ?? '';
          if (name.length < 2) return 'Nhập ít nhất 2 ký tự';
          if (name.length > 80) return 'Tên tối đa 80 ký tự';
          return null;
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: () {
          if (_formKey.currentState!.validate()) {
            Navigator.pop(context, _controller.text.trim());
          }
        },
        child: const Text('Lưu'),
      ),
    ],
  );
}

class _PasswordEditDialog extends StatefulWidget {
  final bool hasPassword;

  const _PasswordEditDialog({required this.hasPassword});

  @override
  State<_PasswordEditDialog> createState() => _PasswordEditDialogState();
}

class _PasswordEditDialogState extends State<_PasswordEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmation = TextEditingController();

  @override
  void dispose() {
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.hasPassword ? 'Đổi mật khẩu' : 'Đặt mật khẩu'),
    content: Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.hasPassword)
              TextFormField(
                controller: _currentPassword,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                decoration: const InputDecoration(
                  labelText: 'Mật khẩu hiện tại',
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Nhập mật khẩu hiện tại'
                    : null,
              ),
            TextFormField(
              controller: _newPassword,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              decoration: const InputDecoration(
                labelText: 'Mật khẩu mới (ít nhất 10 ký tự)',
              ),
              validator: (value) =>
                  value == null || value.length < 10 || value.length > 72
                  ? 'Mật khẩu cần từ 10 đến 72 ký tự'
                  : null,
            ),
            TextFormField(
              controller: _confirmation,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Nhập lại mật khẩu mới',
              ),
              validator: (value) => value != _newPassword.text
                  ? 'Mật khẩu nhập lại chưa khớp'
                  : null,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(context, {
            if (widget.hasPassword) 'currentPassword': _currentPassword.text,
            'newPassword': _newPassword.text,
          });
        },
        child: Text(widget.hasPassword ? 'Cập nhật' : 'Tạo mật khẩu'),
      ),
    ],
  );
}

class Home extends StatefulWidget {
  final Map<String, dynamic> user;
  const Home({super.key, required this.user});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  List<dynamic> children = [], users = [];
  Map<String, dynamic> stats = {};
  bool loading = true;
  String? error;
  int page = 0;
  String get role => widget.user['role'];
  bool get isParent => role == 'parent';
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      if (role == 'admin') {
        users = await api.call('GET', '/admin/users');
        stats = Map<String, dynamic>.from(
          await api.call('GET', '/staff/dashboard'),
        );
      } else if (role == 'staff') {
        stats = Map<String, dynamic>.from(
          await api.call('GET', '/staff/dashboard'),
        );
      } else {
        children = await api.call('GET', '/children');
      }
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> manageUser(Map<String, dynamic> user) async {
    const labels = {
      'parent': 'Phụ huynh',
      'child': 'Trẻ em',
      'staff': 'Nhân viên',
      'admin': 'Quản trị viên',
    };
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(user['name']),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user['email']),
            Text('Vai trò: ${labels[user['role']] ?? user['role']}'),
            Text(
              user['verified'] == true
                  ? 'Email đã xác minh'
                  : 'Email chưa xác minh',
            ),
            const SizedBox(height: 16),
            if (user['role'] == 'admin')
              const Text(
                'Tài khoản quản trị được bảo vệ, không thể đổi quyền tại đây.',
              )
            else
              ...['parent', 'child', 'staff'].map(
                (role) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(labels[role]!),
                  trailing: user['role'] == role
                      ? const Icon(Icons.check)
                      : const Icon(Icons.chevron_right),
                  onTap: user['role'] == role
                      ? null
                      : () => Navigator.pop(ctx, role),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
    if (selected == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận đổi quyền'),
        content: Text('Đổi ${user['name']} thành ${labels[selected]}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await execute(() async {
      await api.call('PATCH', '/admin/users/${user['id']}/role', {
        'role': selected,
      });
      if (mounted) {
        notify(context, 'Đã cập nhật quyền thành ${labels[selected]}');
      }
    });
  }

  Future<void> execute(Future<void> Function() fn) async {
    try {
      await fn();
      await load();
    } catch (e) {
      if (mounted) notify(context, e);
    }
  }

  Future<void> editChild([Map<String, dynamic>? c]) async {
    final result = await editDialog(
      context,
      c == null ? 'Thêm hồ sơ trẻ' : 'Sửa hồ sơ trẻ',
      {
        'name': ('Tên trẻ', c?['name'] ?? ''),
        'age': ('Tuổi', '${c?['age'] ?? 8}'),
        'daily_limit': ('Giới hạn phút/ngày', '${c?['daily_limit'] ?? 120}'),
      },
    );
    if (result == null) return;
    await execute(() async {
      await api.call(
        c == null ? 'POST' : 'PUT',
        c == null ? '/children' : '/children/${c['id']}',
        {
          'name': result['name'],
          'age': int.tryParse(result['age'] ?? '') ?? 0,
          'daily_limit': int.tryParse(result['daily_limit'] ?? '') ?? 0,
        },
      );
    });
  }

  Future<void> logout() async {
    await api.logout();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const Login()));
  }

  Future<void> editProfile() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _ProfileEditDialog(
        initialName: widget.user['name']?.toString() ?? '',
      ),
    );
    if (name == null || !mounted) return;
    try {
      final updated = Map<String, dynamic>.from(
        await api.call('PATCH', '/me', {'name': name}),
      );
      if (!mounted) return;
      setState(() => widget.user.addAll(updated));
      notify(context, 'Đã cập nhật hồ sơ');
    } catch (e) {
      if (mounted) notify(context, e);
    }
  }

  Future<void> updateFontScale(double scale) async {
    try {
      await saveFontScale(scale);
    } catch (e) {
      if (mounted) notify(context, e);
    }
  }

  Future<void> updateBackground(Color color) async {
    try {
      await saveBackground(color);
    } catch (e) {
      if (mounted) notify(context, e);
    }
  }

  Future<void> updateDarkMode(bool enabled) async {
    try {
      await saveDarkMode(enabled);
    } catch (e) {
      if (mounted) notify(context, e);
    }
  }

  Future<void> chooseBackground() async {
    final selected = await showDialog<Color>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Chọn màu nền'),
        children: [
          for (final entry in backgroundOptions.entries)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, entry.value),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: entry.value,
                    child: appBackground.value == entry.value
                        ? const Icon(Icons.check_rounded, size: 16, color: ink)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(entry.key)),
                  if (appBackground.value == entry.value)
                    const Icon(Icons.check_rounded, color: green, size: 18),
                ],
              ),
            ),
        ],
      ),
    );
    if (selected != null) await updateBackground(selected);
  }

  Future<void> enableFinger() async {
    try {
      final auth = FingerprintAuth();
      if (!mounted) return;
      final method = await auth.chooseMethod(context);
      if (mounted && await auth.authenticate(context, method)) {
        await Api.storage.write(
          key: 'biometric_method',
          value: auth.methodKey(method),
        );
        await Api.storage.write(
          key: 'biometric_user_id',
          value: widget.user['id'].toString(),
        );
        await Api.storage.write(key: 'biometric_token', value: api.token);
        if (mounted) {
          notify(
            context,
            'Đã bật mở phiên bằng ${method == BiometricType.face
                ? 'khuôn mặt'
                : method == BiometricType.fingerprint
                ? 'vân tay'
                : 'sinh trắc học của thiết bị'}. Phiên hết hạn sau 12 giờ; sau đó cần OTP.',
          );
        }
      }
    } catch (e) {
      if (mounted) notify(context, e);
    }
  }

  Future<void> changePassword() async {
    final hasPassword = widget.user['hasPassword'] == true;
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _PasswordEditDialog(hasPassword: hasPassword),
    );
    if (result == null || !mounted) return;
    await execute(() async {
      await api.call('PATCH', '/me/password', result);
      if (mounted) {
        notify(
          context,
          hasPassword
              ? 'Đã đổi mật khẩu'
              : 'Đã đặt mật khẩu. Bạn có thể đăng nhập bằng mật khẩu và OTP.',
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Row(
        children: [
          const BrandMark(size: 42),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'An Tâm Số',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
              Text(
                role == 'admin'
                    ? 'KHU VỰC QUẢN TRỊ'
                    : role == 'staff'
                    ? 'KHU VỰC NHÂN VIÊN'
                    : 'GIA ĐÌNH CỦA BẠN',
                style: const TextStyle(
                  color: Color(0xFF77857A),
                  fontSize: 9,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Làm mới',
          onPressed: load,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: page,
      onDestinationSelected: (i) => setState(() => page = i),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.space_dashboard_outlined),
          label: 'Tổng quan',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          label: 'Cài đặt',
        ),
      ],
    ),
    floatingActionButton: page == 0 && isParent
        ? FloatingActionButton.extended(
            onPressed: () => editChild(),
            icon: const Icon(Icons.add),
            label: const Text('Thêm trẻ'),
          )
        : null,
    body: page == 1
        ? ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFE7EFE3),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.white,
                      foregroundColor: green,
                      child: Text(
                        initials(widget.user['name']),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 19,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.user['name'],
                            style: const TextStyle(
                              color: ink,
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.user['email'],
                            style: const TextStyle(color: Color(0xFF68796D)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Cài đặt giao diện',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: Icon(
                          appDarkMode.value
                              ? Icons.dark_mode_rounded
                              : Icons.light_mode_rounded,
                          color: green,
                        ),
                        title: const Text('Giao diện tối'),
                        subtitle: Text(
                          appDarkMode.value
                              ? 'Đang bật chế độ tối'
                              : 'Đang dùng chế độ sáng',
                        ),
                        value: appDarkMode.value,
                        onChanged: updateDarkMode,
                      ),
                      const Divider(height: 20),
                      const Text(
                        'Cỡ chữ',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Row(
                        children: [
                          const Text('A', style: TextStyle(fontSize: 12)),
                          Expanded(
                            child: Slider(
                              min: minFontScale,
                              max: maxFontScale,
                              divisions: 12,
                              value: appFontScale.value,
                              label: '${(appFontScale.value * 100).round()}%',
                              onChanged: (value) {
                                appFontScale.value = value;
                              },
                              onChangeEnd: updateFontScale,
                            ),
                          ),
                          const Text(
                            'A',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Màu nền',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          backgroundOptions.entries
                              .firstWhere(
                                (entry) => entry.value == appBackground.value,
                              )
                              .key,
                        ),
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: appBackground.value,
                          child: const Icon(
                            Icons.palette_outlined,
                            size: 16,
                            color: ink,
                          ),
                        ),
                        trailing: const Icon(Icons.expand_more_rounded),
                        onTap: chooseBackground,
                      ),
                    ],
                  ),
                ),
              ),
              const Text(
                'Tài khoản & bảo mật',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE7EFE3),
                    child: Icon(Icons.edit_outlined, color: green),
                  ),
                  title: const Text('Cập nhật hồ sơ'),
                  subtitle: const Text('Thay đổi tên hiển thị của bạn'),
                  onTap: editProfile,
                ),
              ),
              Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFF9EADB),
                    child: Icon(Icons.badge_outlined, color: coral),
                  ),
                  title: const Text('Vai trò'),
                  subtitle: Text(
                    {
                          'parent': 'Phụ huynh',
                          'child': 'Trẻ em',
                          'staff': 'Nhân viên',
                          'admin': 'Quản trị viên',
                        }[role] ??
                        role,
                  ),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE7EFE3),
                    child: Icon(Icons.lock_outline_rounded, color: green),
                  ),
                  title: Text(
                    widget.user['hasPassword'] == true
                        ? 'Đổi mật khẩu'
                        : 'Đặt mật khẩu đăng nhập',
                  ),
                  subtitle: Text(
                    widget.user['hasPassword'] == true
                        ? 'Xác minh mật khẩu hiện tại trước khi đổi'
                        : 'Tài khoản Google chưa có mật khẩu',
                  ),
                  onTap: changePassword,
                ),
              ),
              Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE7EFE3),
                    child: Icon(Icons.fingerprint_rounded, color: green),
                  ),
                  title: const Text('Bật mở phiên bằng khuôn mặt / vân tay'),
                  subtitle: const Text(
                    'Cần đăng nhập OTP trước; dữ liệu sinh trắc không gửi lên server',
                  ),
                  onTap: enableFinger,
                ),
              ),
              Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFF4EFE4),
                    child: Icon(Icons.lock_reset_rounded, color: ink),
                  ),
                  title: const Text('Tắt mở phiên bằng sinh trắc học'),
                  onTap: () async {
                    try {
                      await Api.clearBiometricSession();
                      if (context.mounted) {
                        notify(context, 'Đã tắt mở phiên bằng sinh trắc học');
                      }
                    } catch (e) {
                      if (context.mounted) notify(context, e);
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: logout,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Đăng xuất khỏi tài khoản'),
                ),
              ),
            ],
          )
        : loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(error!),
                  FilledButton(onPressed: load, child: const Text('Thử lại')),
                ],
              ),
            ),
          )
        : RefreshIndicator(
            onRefresh: load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            role == 'admin'
                                ? 'Xin chào quản trị viên'
                                : role == 'staff'
                                ? 'Xin chào nhân viên'
                                : 'Xin chào, ${widget.user['name']}',
                            style: const TextStyle(
                              fontSize: 24,
                              letterSpacing: -0.6,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            role == 'admin'
                                ? 'Quản lý tài khoản và hoạt động hệ thống'
                                : role == 'staff'
                                ? 'Tổng quan vận hành dành cho nhân viên'
                                : role == 'child'
                                ? 'Không gian gia đình đã được liên kết'
                                : 'Cùng con xây dựng thói quen số lành mạnh',
                            style: const TextStyle(
                              color: Color(0xFF77857A),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: const Color(0xFFF4E4D7),
                      foregroundColor: ink,
                      child: Text(
                        initials(widget.user['name']),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7EFE3),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              role == 'admin' || role == 'staff'
                                  ? 'Cùng nhau chăm sóc tốt hơn'
                                  : 'Nếp nhỏ, ngày an vui',
                              style: const TextStyle(
                                color: ink,
                                fontSize: 20,
                                height: 1.2,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              role == 'admin' || role == 'staff'
                                  ? 'Thông tin được tổng hợp theo đúng quyền truy cập.'
                                  : 'Thỏa thuận tích cực giúp cả nhà cùng thống nhất thời gian số.',
                              style: const TextStyle(
                                color: Color(0xFF637469),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 66,
                        height: 82,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF4E7),
                          borderRadius: BorderRadius.circular(32),
                        ),
                        child: const Icon(
                          Icons.spa_rounded,
                          color: coral,
                          size: 38,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                if (role == 'admin' || role == 'staff') ...[
                  const Text(
                    'Số liệu tổng quan',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: stats.entries
                        .map(
                          (e) => Container(
                            width: 146,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFF0EBDD),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  e.key == 'users'
                                      ? Icons.people_alt_outlined
                                      : e.key == 'children'
                                      ? Icons.child_care_rounded
                                      : Icons.phone_android_rounded,
                                  color: green,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  '${e.value}',
                                  style: const TextStyle(
                                    color: ink,
                                    fontSize: 23,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  e.key == 'users'
                                      ? 'Tài khoản'
                                      : e.key == 'children'
                                      ? 'Hồ sơ trẻ'
                                      : 'Thiết bị',
                                  style: const TextStyle(
                                    color: Color(0xFF77857A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  if (role == 'staff')
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'Nhân viên xem số liệu tổng hợp để hỗ trợ vận hành. Không truy cập hồ sơ riêng tư của gia đình.',
                        ),
                      ),
                    ),
                  if (role == 'admin') ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Tài khoản người dùng',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                  ...users.map(
                    (u) => Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFE7EFE3),
                          foregroundColor: green,
                          child: Text(initials(u['name'])),
                        ),
                        title: Text(u['name']),
                        subtitle: Text('${u['email']} • ${u['role']}'),
                        onTap: () => manageUser(Map<String, dynamic>.from(u)),
                        trailing: IconButton(
                          tooltip: 'Quản lý tài khoản',
                          onPressed: () =>
                              manageUser(Map<String, dynamic>.from(u)),
                          icon: const Icon(Icons.manage_accounts_outlined),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          role == 'child'
                              ? 'Hồ sơ được liên kết'
                              : 'Hồ sơ gia đình',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (isParent)
                        TextButton.icon(
                          onPressed: () => editChild(),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Thêm'),
                        ),
                    ],
                  ),
                  if (children.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          children: [
                            const BrandMark(size: 58),
                            const SizedBox(height: 12),
                            Text(
                              isParent
                                  ? 'Bắt đầu từ hồ sơ đầu tiên'
                                  : 'Chưa có hồ sơ được liên kết',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: ink,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isParent
                                  ? 'Thêm thông tin của con để thiết lập kế hoạch thời gian số.'
                                  : 'Nhờ phụ huynh liên kết email tài khoản con trong hồ sơ trẻ.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF77857A),
                                height: 1.4,
                              ),
                            ),
                            if (isParent) ...[
                              const SizedBox(height: 14),
                              FilledButton.icon(
                                onPressed: () => editChild(),
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Tạo hồ sơ trẻ'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ...children.map(
                    (c) => Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChildPage(
                                child: Map<String, dynamic>.from(c),
                                isParent: isParent,
                              ),
                            ),
                          );
                          await load();
                        },
                        onLongPress: isParent
                            ? () => editChild(Map<String, dynamic>.from(c))
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 58,
                                height: 58,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9EADB),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Center(
                                  child: Text(
                                    initials(c['name']),
                                    style: const TextStyle(
                                      color: ink,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c['name'],
                                      style: const TextStyle(
                                        color: ink,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      '${c['age']} tuổi  ·  Kế hoạch ${c['daily_limit']} phút/ngày',
                                      style: const TextStyle(
                                        color: Color(0xFF77857A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: Color(0xFF9AA59B),
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
  );
}

Future<Map<String, String>?> editDialog(
  BuildContext context,
  String title,
  Map<String, (String, String)> fields,
) async {
  final controllers = fields.map(
    (key, value) => MapEntry(key, TextEditingController(text: value.$2)),
  );
  final result = await showDialog<Map<String, String>>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: fields.entries
              .map(
                (e) => field(
                  controllers[e.key]!,
                  e.value.$1,
                  keyboard: ['age', 'daily_limit', 'reward'].contains(e.key)
                      ? TextInputType.number
                      : null,
                ),
              )
              .toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            ctx,
            controllers.map((k, v) => MapEntry(k, v.text.trim())),
          ),
          child: const Text('Lưu'),
        ),
      ],
    ),
  );
  // Controllers stay alive until the dialog route has completed its exit animation.
  Future.delayed(const Duration(seconds: 1), () {
    for (final c in controllers.values) {
      c.dispose();
    }
  });
  return result;
}
