part of 'main.dart';

final api = Api();
const ink = Color(0xFF263B32),
    green = Color(0xFF5F866D),
    coral = Color(0xFFE78D72),
    paper = Color(0xFFFBF8F2);

const minFontScale = 0.8;
const maxFontScale = 1.4;
const backgroundOptions = <String, Color>{
  'Kem ấm': paper,
  'Xanh nhạt': Color(0xFFF2F7F1),
  'Xanh lam nhạt': Color(0xFFF0F4FA),
};
final appFontScale = ValueNotifier<double>(1);
final appBackground = ValueNotifier<Color>(paper);
final appDarkMode = ValueNotifier<bool>(false);
final appNavigatorKey = GlobalKey<NavigatorState>();

const sessionTimeout = Duration(seconds: 30);
const _backgroundedAtKey = 'app_backgrounded_at';

bool isValidFontScale(double scale) {
  final step = (scale * 20).roundToDouble();
  return scale >= minFontScale &&
      scale <= maxFontScale &&
      (scale * 20 - step).abs() <= 0.001;
}

Future<void> loadAppPreferences() async {
  appDarkMode.value = await Api.storage.read(key: 'dark_mode') == 'true';
  final savedScale = await Api.storage.read(key: 'font_scale');
  final scale = double.tryParse(savedScale ?? '');
  if (scale != null && isValidFontScale(scale)) {
    appFontScale.value = scale;
  }
  final savedBackground = await Api.storage.read(key: 'app_background');
  for (final color in backgroundOptions.values) {
    if (color.toARGB32().toRadixString(16) == savedBackground) {
      appBackground.value = color;
      break;
    }
  }
}

Future<void> saveDarkMode(bool enabled) async {
  await Api.storage.write(key: 'dark_mode', value: enabled.toString());
  appDarkMode.value = enabled;
}

Future<void> saveFontScale(double scale) async {
  if (!isValidFontScale(scale)) {
    throw ArgumentError.value(scale, 'scale', 'Cỡ chữ không hợp lệ');
  }
  await Api.storage.write(key: 'font_scale', value: scale.toStringAsFixed(2));
  appFontScale.value = scale;
}

Future<void> saveBackground(Color color) async {
  if (!backgroundOptions.values.contains(color)) {
    throw ArgumentError.value(color, 'color', 'Màu nền không hợp lệ');
  }
  await Api.storage.write(
    key: 'app_background',
    value: color.toARGB32().toRadixString(16),
  );
  appBackground.value = color;
}

class AnTamSo extends StatefulWidget {
  const AnTamSo({super.key});

  @override
  State<AnTamSo> createState() => _AnTamSoState();
}

class _AnTamSoState extends State<AnTamSo> {
  String? preferenceError;

  @override
  void initState() {
    super.initState();
    loadAppPreferences().catchError((Object error) {
      if (mounted) setState(() => preferenceError = error.toString());
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([appFontScale, appBackground, appDarkMode]),
    builder: (context, _) {
      final darkMode = appDarkMode.value;
      final scaffoldColor = darkMode
          ? const Color(0xFF151B18)
          : appBackground.value;
      final surfaceColor = darkMode ? const Color(0xFF222A25) : Colors.white;
      final borderColor = darkMode
          ? const Color(0xFF37433B)
          : const Color(0xFFF0EBDD);
      return MaterialApp(
        title: 'An Tâm Số',
        navigatorKey: appNavigatorKey,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: darkMode ? Brightness.dark : Brightness.light,
          colorScheme: ColorScheme.fromSeed(
            seedColor: green,
            brightness: darkMode ? Brightness.dark : Brightness.light,
          ),
          scaffoldBackgroundColor: scaffoldColor,
          appBarTheme: AppBarTheme(
            backgroundColor: scaffoldColor,
            foregroundColor: darkMode ? Colors.white : ink,
            centerTitle: false,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: darkMode
                ? const Color(0xFF2C352F)
                : const Color(0xFFF8F5EE),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 18,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: green, width: 1.5),
            ),
          ),
          cardTheme: CardThemeData(
            elevation: 0,
            color: surfaceColor,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: borderColor),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: darkMode ? const Color(0xFF222A25) : Colors.white,
            indicatorColor: darkMode
                ? const Color(0xFF3A5143)
                : const Color(0xFFE6EFE5),
            elevation: 2,
            labelTextStyle: WidgetStateProperty.all(
              const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        builder: (context, child) {
          final content = child ?? const SizedBox.shrink();
          return _SessionTimeout(
            child: Column(
              children: [
                if (preferenceError != null)
                  MaterialBanner(
                    content: Text('Không tải được cài đặt: $preferenceError'),
                    actions: [
                      TextButton(
                        onPressed: () => setState(() => preferenceError = null),
                        child: const Text('Đóng'),
                      ),
                    ],
                  ),
                Expanded(
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(appFontScale.value),
                    ),
                    child: content,
                  ),
                ),
              ],
            ),
          );
        },
        home: const SessionGate(),
      );
    },
  );
}

class _SessionTimeout extends StatefulWidget {
  final Widget child;

  const _SessionTimeout({required this.child});

  @override
  State<_SessionTimeout> createState() => _SessionTimeoutState();
}

class _SessionTimeoutState extends State<_SessionTimeout>
    with WidgetsBindingObserver {
  DateTime? _backgroundedAt;

  @override
  Widget build(BuildContext context) => widget.child;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _backgroundedAt ??= DateTime.now();
      unawaited(
        Api.storage.write(
          key: _backgroundedAtKey,
          value: _backgroundedAt!.millisecondsSinceEpoch.toString(),
        ),
      );
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_resumeSession());
    }
  }

  Future<void> _resumeSession() async {
    final backgroundedAt = _backgroundedAt;
    _backgroundedAt = null;
    if (backgroundedAt == null) return;

    await Api.storage.delete(key: _backgroundedAtKey);
    if (DateTime.now().difference(backgroundedAt) < sessionTimeout) return;

    final token = await Api.storage.read(key: 'session_token');
    if (token == null) return;

    await api.logout();
    appNavigatorKey.currentState?.pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(
        builder: (_) => const Login(sessionExpired: true),
      ),
      (_) => false,
    );
  }
}

class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key, this.size = 52});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFFE7EFE3),
            borderRadius: BorderRadius.circular(size * .36),
          ),
        ),
        Icon(Icons.home_rounded, size: size * .62, color: ink),
        Positioned(
          right: size * .14,
          top: size * .14,
          child: Container(
            width: size * .24,
            height: size * .24,
            decoration: const BoxDecoration(
              color: coral,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    ),
  );
}

String initials(Object? value) {
  final parts = value?.toString().trim().split(RegExp(r'\s+')) ?? [];
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  return parts.length == 1
      ? parts.first.substring(0, 1).toUpperCase()
      : '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
            .toUpperCase();
}

void notify(BuildContext context, Object text) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text.toString().replaceFirst('Exception: ', ''))),
    );
Widget field(
  TextEditingController controller,
  String label, {
  bool secret = false,
  TextInputType? keyboard,
}) => Padding(
  padding: const EdgeInsets.only(bottom: 14),
  child: TextField(
    controller: controller,
    obscureText: secret,
    keyboardType: keyboard,
    decoration: InputDecoration(labelText: label),
  ),
);
