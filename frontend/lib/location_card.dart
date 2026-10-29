import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';

class LocationCard extends StatefulWidget {
  const LocationCard({
    super.key,
    required this.api,
    required this.childId,
    required this.canShare,
  });

  final Api api;
  final String childId;
  final bool canShare;

  @override
  State<LocationCard> createState() => _LocationCardState();
}

class _LocationCardState extends State<LocationCard> {
  Map<String, dynamic>? location;
  bool busy = false;
  String? error;

  String get path => '/children/${widget.childId}/location';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> load() => run(() async {
    final result = await widget.api.call('GET', path);
    location = result == null ? null : Map<String, dynamic>.from(result);
  });

  Future<void> share() async {
    final agreed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chia sẻ vị trí với phụ huynh?'),
        content: const Text(
          'Ứng dụng sẽ gửi vị trí hiện tại và độ chính xác của điện thoại lên máy chủ để phụ huynh liên kết xem. Không theo dõi trong nền. Bạn có thể ngừng chia sẻ và xóa vị trí bất cứ lúc nào.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Để sau'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Đồng ý chia sẻ'),
          ),
        ],
      ),
    );
    if (agreed != true || !mounted) return;

    await run(() async {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Hãy bật dịch vụ vị trí trên điện thoại.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Quyền vị trí bị khóa. Hãy mở Cài đặt ứng dụng để cấp quyền.',
        );
      }
      if (permission == LocationPermission.denied) {
        throw Exception('Bạn chưa cho phép truy cập vị trí.');
      }

      final point = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 25),
        ),
      );
      location = Map<String, dynamic>.from(
        await widget.api.call('PUT', path, {
          'latitude': point.latitude,
          'longitude': point.longitude,
          'accuracy': point.accuracy,
        }),
      );
    });
  }

  Future<void> openMap() async {
    if (location == null) return;
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '${location!['latitude']},${location!['longitude']}',
    });
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
          mounted) {
        setState(() => error = 'Không mở được ứng dụng bản đồ.');
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = 'Không mở được ứng dụng bản đồ: '
              '${e.toString().replaceFirst('Exception: ', '')}',
        );
      }
    }
  }

  Future<void> stopSharing() => run(() async {
    await widget.api.call('DELETE', path);
    location = null;
  });

  @override
  Widget build(BuildContext context) {
    final updatedAt = location == null
        ? null
        : DateTime.parse(location!['updated_at']).toLocal();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFE7EFE3),
                  child: Icon(
                    Icons.location_on_outlined,
                    color: Color(0xFF5F866D),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Chia sẻ vị trí',
                    style: TextStyle(
                      color: Color(0xFF263B32),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Làm mới',
                  onPressed: busy ? null : load,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (location == null)
              const Text(
                'Chưa có vị trí được chia sẻ.',
                style: TextStyle(color: Color(0xFF77857A)),
              )
            else ...[
              Text(
                'Cập nhật lúc ${updatedAt!.toString().split('.').first}',
                style: const TextStyle(
                  color: Color(0xFF263B32),
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Độ chính xác khoảng ${location!['accuracy']} m',
                style: const TextStyle(color: Color(0xFF77857A)),
              ),
              const SizedBox(height: 4),
              const Text(
                'Đây là vị trí tại thời điểm chia sẻ, không phải theo dõi trực tiếp.',
                style: TextStyle(
                  color: Color(0xFF77857A),
                  height: 1.35,
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: openMap,
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Xem trên bản đồ'),
                ),
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                error!,
                style: const TextStyle(color: Color(0xFFC36855)),
              ),
            ],
            if (busy) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(),
            ] else ...[
              if (widget.canShare)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: share,
                    icon: const Icon(Icons.my_location_rounded),
                    label: const Text('Chia sẻ vị trí hiện tại'),
                  ),
                ),
              if (widget.canShare && location != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: stopSharing,
                    child: const Text('Ngừng & xóa vị trí'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
