part of 'main.dart';

class ChildPage extends StatefulWidget {
  final Map<String, dynamic> child;
  final bool isParent;
  const ChildPage({super.key, required this.child, required this.isParent});
  @override
  State<ChildPage> createState() => _ChildPageState();
}

class _ChildPageState extends State<ChildPage> {
  List<dynamic> devices = [], agreements = [], checkins = [];
  bool busy = true;
  String? error;
  String get id => widget.child['id'];
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    NfcManager.instance.stopSession();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final r = await Future.wait([
        api.call('GET', '/children/$id/devices'),
        api.call('GET', '/children/$id/agreements'),
        api.call('GET', '/children/$id/checkins'),
      ]);
      devices = r[0];
      agreements = r[1];
      checkins = r[2];
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> act(Future<void> Function() f) async {
    try {
      await f();
      await load();
    } catch (e) {
      if (mounted) notify(context, e);
    }
  }

  Future<void> device([Map<String, dynamic>? d]) async {
    final b = await editDialog(
      context,
      d == null ? 'Thêm thiết bị' : 'Đổi tên thiết bị',
      {'name': ('Tên điện thoại', d?['name'] ?? '')},
    );
    if (b == null) return;
    await act(() async {
      await api.call(
        d == null ? 'POST' : 'PUT',
        d == null ? '/children/$id/devices' : '/devices/${d['id']}',
        b,
      );
    });
  }

  Future<void> agreement() async {
    final b = await editDialog(context, 'Thỏa thuận thời gian số', {
      'title': ('Mục tiêu (ví dụ đọc sách 30 phút)', ''),
      'reward': ('Phút thưởng', '15'),
    });
    if (b == null) return;
    await act(() async {
      await api.call('POST', '/children/$id/agreements', {
        'title': b['title'],
        'reward': int.tryParse(b['reward'] ?? '') ?? 0,
      });
    });
  }

  Future<void> nfc(bool enroll) async {
    try {
      if (!await NfcManager.instance.isAvailable()) {
        throw Exception('Thiết bị không hỗ trợ NFC hoặc NFC chưa bật.');
      }
      if (!mounted) return;
      bool scanned = false;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text(enroll ? 'Gắn thẻ NFC' : 'Check-in NFC'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.nfc, size: 64, color: green),
              SizedBox(height: 16),
              Text('Đưa thẻ đến mặt sau điện thoại.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await NfcManager.instance.stopSession();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Hủy'),
            ),
          ],
        ),
      );
      await NfcManager.instance.startSession(
        onDiscovered: (tag) async {
          if (scanned) return;
          scanned = true;
          try {
            List<int>? uid;
            for (final key in [
              'nfca',
              'nfcb',
              'nfcf',
              'nfcv',
              'mifareclassic',
              'mifareultralight',
              'isodep',
            ]) {
              final d = tag.data[key];
              if (d is Map && d['identifier'] is List) {
                uid = List<int>.from(d['identifier']);
                break;
              }
            }
            if (uid == null || uid.isEmpty) {
              throw Exception('Thẻ không có UID được hỗ trợ');
            }
            final tagHash = sha256.convert(uid).toString();
            await api.call(
              enroll ? 'PUT' : 'POST',
              '/children/$id/${enroll ? 'nfc' : 'checkins'}',
              {'tagHash': tagHash},
            );
            await NfcManager.instance.stopSession();
            if (mounted) {
              Navigator.pop(context);
              notify(context, enroll ? 'Đã gắn thẻ' : 'Check-in thành công');
              await load();
            }
          } catch (e) {
            await NfcManager.instance.stopSession();
            if (mounted) {
              Navigator.pop(context);
              notify(context, e);
            }
          }
        },
      );
    } on PlatformException catch (e) {
      if (mounted) notify(context, e.message ?? 'Lỗi NFC');
    } catch (e) {
      if (mounted) notify(context, e);
    }
  }

  Future<bool> confirm(String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Xác nhận xóa'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Xóa'),
            ),
          ],
        ),
      ) ??
      false;
  @override
  Widget build(BuildContext context) {
    final bonus = agreements
        .where((a) => a['status'] == 'approved')
        .fold<int>(0, (sum, a) => sum + (a['reward'] as int));
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.child['name'],
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const Text(
              'HỒ SƠ GIA ĐÌNH',
              style: TextStyle(
                color: Color(0xFF77857A),
                fontSize: 9,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
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
      body: busy
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
              child: TextButton(
                onPressed: load,
                child: Text('$error\nThử lại'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7EFE3),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF4E7),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Center(
                              child: Text(
                                initials(widget.child['name']),
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
                                  widget.child['name'],
                                  style: const TextStyle(
                                    color: ink,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${widget.child['age']} tuổi  ·  Kế hoạch gia đình',
                                  style: const TextStyle(
                                    color: Color(0xFF66776B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.wb_sunny_outlined,
                            color: coral,
                            size: 25,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .72),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.schedule_rounded,
                              color: green,
                              size: 26,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Thời gian đã thống nhất',
                                    style: TextStyle(
                                      color: Color(0xFF66776B),
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    '${widget.child['daily_limit']} phút / ngày',
                                    style: const TextStyle(
                                      color: ink,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(
                            Icons.stars_rounded,
                            color: Color(0xFFB97555),
                            size: 19,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$bonus phút thưởng đã được duyệt',
                            style: const TextStyle(
                              color: Color(0xFF596B5E),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1E8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: Color(0xFFB97555),
                        size: 20,
                      ),
                      SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'Đây là kế hoạch gia đình đã lưu, chưa theo dõi hay chặn ứng dụng trên điện thoại.',
                          style: TextStyle(
                            color: Color(0xFF795B49),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.isParent) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          final b = await editDialog(context, 'Sửa hồ sơ', {
                            'name': ('Tên', widget.child['name']),
                            'age': ('Tuổi', '${widget.child['age']}'),
                            'daily_limit': (
                              'Phút/ngày',
                              '${widget.child['daily_limit']}',
                            ),
                          });
                          if (b == null) return;
                          await act(() async {
                            final r = await api.call('PUT', '/children/$id', {
                              'name': b['name'],
                              'age': int.tryParse(b['age'] ?? '') ?? 0,
                              'daily_limit':
                                  int.tryParse(b['daily_limit'] ?? '') ?? 0,
                            });
                            widget.child.addAll(Map<String, dynamic>.from(r));
                          });
                        },
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Sửa hồ sơ'),
                      ),
                      OutlinedButton(
                        onPressed: () async {
                          final b = await editDialog(
                            context,
                            'Liên kết tài khoản trẻ',
                            {
                              'email': (
                                'Email tài khoản trẻ đã được admin cấp quyền',
                                '',
                              ),
                            },
                          );
                          if (b != null) {
                            await act(() async {
                              await api.call('POST', '/children/$id/link', b);
                              if (context.mounted) {
                                notify(context, 'Đã liên kết');
                              }
                            });
                          }
                        },
                        child: const Text('Liên kết trẻ'),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 22),
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Thiết bị',
                            style: TextStyle(
                              color: ink,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Danh sách thiết bị đã ghi trong hồ sơ',
                            style: TextStyle(
                              color: Color(0xFF77857A),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.isParent)
                      IconButton.filledTonal(
                        onPressed: () => device(),
                        icon: const Icon(Icons.add_rounded),
                        tooltip: 'Thêm thiết bị',
                      ),
                  ],
                ),
                if (devices.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Chưa có thiết bị. Bạn có thể thêm tên điện thoại để hoàn thiện hồ sơ.',
                      style: TextStyle(color: Color(0xFF77857A), height: 1.4),
                    ),
                  ),
                ...devices.map(
                  (d) => Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE7EFE3),
                        child: Icon(Icons.phone_iphone_rounded, color: green),
                      ),
                      title: Text(d['name']),
                      subtitle: const Text('Android · thông tin hồ sơ'),
                      onTap: widget.isParent
                          ? () => device(Map<String, dynamic>.from(d))
                          : null,
                      trailing: widget.isParent
                          ? IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                if (await confirm('Xóa thiết bị này?')) {
                                  await act(() async {
                                    await api.call(
                                      'DELETE',
                                      '/devices/${d['id']}',
                                    );
                                  });
                                }
                              },
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Thỏa thuận gia đình',
                            style: TextStyle(
                              color: ink,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Cùng đặt mục tiêu và phần thưởng phù hợp',
                            style: TextStyle(
                              color: Color(0xFF77857A),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: agreement,
                      icon: const Icon(Icons.add_rounded),
                      tooltip: 'Tạo thỏa thuận',
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Trẻ có thể đề xuất mục tiêu; phụ huynh duyệt phần thưởng.',
                  style: TextStyle(color: Color(0xFF77857A), height: 1.4),
                ),
                if (agreements.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      'Chưa có thỏa thuận nào. Hãy bắt đầu bằng một mục tiêu nhỏ.',
                      style: TextStyle(color: Color(0xFF77857A), height: 1.4),
                    ),
                  ),
                ...agreements.map((a) {
                  final statusColor = a['status'] == 'approved'
                      ? green
                      : a['status'] == 'rejected'
                      ? const Color(0xFFC36855)
                      : const Color(0xFFB97555);
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  a['title'],
                                  style: const TextStyle(
                                    color: ink,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: .12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '+${a['reward']} phút',
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                a['status'] == 'approved'
                                    ? Icons.check_circle_outline_rounded
                                    : a['status'] == 'rejected'
                                    ? Icons.cancel_outlined
                                    : Icons.hourglass_empty_rounded,
                                size: 17,
                                color: statusColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                {
                                      'pending': 'Đang chờ phụ huynh',
                                      'approved': 'Đã được duyệt',
                                      'rejected': 'Chưa được duyệt',
                                    }[a['status']] ??
                                    'Chưa xác định',
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          if (widget.isParent)
                            Wrap(
                              spacing: 4,
                              children: [
                                if (a['status'] == 'pending')
                                  TextButton(
                                    onPressed: () => act(() async {
                                      await api.call(
                                        'PATCH',
                                        '/agreements/${a['id']}',
                                        {'status': 'approved'},
                                      );
                                    }),
                                    child: const Text('Duyệt'),
                                  ),
                                if (a['status'] == 'pending')
                                  TextButton(
                                    onPressed: () => act(() async {
                                      await api.call(
                                        'PATCH',
                                        '/agreements/${a['id']}',
                                        {'status': 'rejected'},
                                      );
                                    }),
                                    child: const Text('Từ chối'),
                                  ),
                                TextButton(
                                  onPressed: () async {
                                    if (await confirm('Xóa thỏa thuận này?')) {
                                      await act(() async {
                                        await api.call(
                                          'DELETE',
                                          '/agreements/${a['id']}',
                                        );
                                      });
                                    }
                                  },
                                  child: const Text('Xóa'),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 12),
                LocationCard(api: api, childId: id, canShare: !widget.isParent),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9EADB),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.nfc_rounded,
                            color: Color(0xFFB97555),
                            size: 25,
                          ),
                          const SizedBox(width: 9),
                          const Expanded(
                            child: Text(
                              'Chạm thẻ NFC',
                              style: TextStyle(
                                color: ink,
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (widget.isParent)
                            TextButton(
                              onPressed: () => nfc(true),
                              child: const Text('Gắn thẻ'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Dùng thẻ đã gắn để ghi nhận check-in. UID không xác minh danh tính hoặc vị trí.',
                        style: TextStyle(color: Color(0xFF795B49), height: 1.4),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: () => nfc(false),
                          icon: const Icon(Icons.tap_and_play_rounded),
                          label: const Text('Bắt đầu check-in'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Lịch sử check-in',
                  style: TextStyle(
                    color: ink,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (checkins.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Chưa có lượt check-in nào được ghi nhận.',
                      style: TextStyle(color: Color(0xFF77857A)),
                    ),
                  ),
                ...checkins.map(
                  (c) => ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE7EFE3),
                      child: Icon(Icons.check_rounded, color: green),
                    ),
                    title: const Text('Check-in thành công'),
                    subtitle: Text(
                      DateTime.parse(
                        c['created_at'],
                      ).toLocal().toString().split('.').first,
                    ),
                  ),
                ),
                if (widget.isParent) ...[
                  const SizedBox(height: 32),
                  TextButton.icon(
                    onPressed: () async {
                      if (!await confirm(
                        'Xóa hồ sơ cùng thiết bị, thỏa thuận và lịch sử check-in?',
                      )) {
                        return;
                      }
                      try {
                        await api.call('DELETE', '/children/$id');
                        if (context.mounted) Navigator.pop(context);
                      } catch (e) {
                        if (context.mounted) notify(context, e);
                      }
                    },
                    icon: const Icon(Icons.delete_forever, color: Colors.red),
                    label: const Text(
                      'Xóa hồ sơ trẻ',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
                const SizedBox(height: 30),
              ],
            ),
    );
  }
}
