part of 'main.dart';

final api = Api();
const ink = Color(0xFF263B32),
    green = Color(0xFF5F866D),
    coral = Color(0xFFE78D72),
    paper = Color(0xFFFBF8F2);

class AnTamSo extends StatelessWidget {
  const AnTamSo({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'An Tâm Số',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: green),
      scaffoldBackgroundColor: paper,
      appBarTheme: const AppBarTheme(
        backgroundColor: paper,
        foregroundColor: ink,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8F5EE),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFEAE5D9)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFEAE5D9)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: green, width: 1.5),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFF0EBDD)),
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
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFE6EFE5),
        elevation: 2,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    ),
    home: const Login(),
  );
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
