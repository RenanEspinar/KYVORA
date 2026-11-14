import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'core.dart';
part 'training.dart';

part 'community.dart';
part 'account.dart';

Map<String, Map<String, dynamic>> exerciseMotions = {};

const lime = Color(0xFFB5FF39),
    muted = Color(0xFFA6ADB4),
    surface = Color(0xFF1C2024),
    canvas = Color(0xFF101214);
const destinations = [
  '/inicio',
  '/entrenar',
  '/comunidad',
  '/rankings',
  '/perfil',
];
final routes = GoRouter(
  initialLocation: '/inicio',
  routes: [
    ShellRoute(
      builder: (c, s, child) => Shell(child: child),
      routes: [
        GoRoute(path: '/inicio', builder: (_, _) => const Home()),
        GoRoute(path: '/entrenar', builder: (_, _) => const Training()),
        GoRoute(path: '/comunidad', builder: (_, _) => const Feed()),
        GoRoute(path: '/rankings', builder: (_, _) => const Rankings()),
        GoRoute(path: '/perfil', builder: (_, _) => const ProfilePage()),
      ],
    ),
    GoRoute(
      path: '/sesion/:id',
      builder: (_, s) => SessionPage(id: s.pathParameters['id']!),
    ),
    GoRoute(path: '/cuenta', builder: (_, _) => const Access()),
  ],
);
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final data = jsonDecode(await rootBundle.loadString('assets/motion_index.json')) as Map;
    exerciseMotions = data.map((key, value) => MapEntry(key.toString(), Map<String, dynamic>.from(value as Map)));
  } catch (_) {
    exerciseMotions = {};
  }
  final a = LogState(await Store.open(), Api());
  await a.init();
  runApp(
    ProviderScope(
      overrides: [stateProvider.overrideWith((_) => a)],
      child: const Liftlog(),
    ),
  );
}

class Liftlog extends StatelessWidget {
  const Liftlog({super.key});
  @override
  Widget build(BuildContext c) => MaterialApp.router(
    title: 'LIFTLOG',
    debugShowCheckedModeBanner: false,
    routerConfig: routes,
    locale: const Locale('es'),
    supportedLocales: const [Locale('es'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: canvas,
      colorScheme: const ColorScheme.dark(
        primary: lime,
        onPrimary: canvas,
        surface: surface,
        onSurface: Colors.white,
        secondary: lime,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: canvas,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: canvas,
        indicatorColor: lime.withValues(alpha: .18),
        height: 72,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF282D32),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          letterSpacing: -1,
        ),
        titleLarge: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
      ),
    ),
  );
}

class Shell extends ConsumerStatefulWidget {
  final Widget child;
  const Shell({super.key, required this.child});
  @override
  ConsumerState<Shell> createState() => _Shell();
}

class _Shell extends ConsumerState<Shell> with WidgetsBindingObserver {
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
    if (state == AppLifecycleState.resumed) ref.read(stateProvider).sync();
  }

  @override
  Widget build(BuildContext c) {
    final a = ref.watch(stateProvider);
    final pending = a.workouts
        .where((w) => w['state'] == 'pending' || w['state'] == 'conflict')
        .length;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (pending > 0)
              InkWell(
                onTap: () => a.sync(force: true),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  color: const Color(0xFF273321),
                  child: Text(
                    '$pending guardados · pendientes de sincronizar',
                    style: const TextStyle(color: lime, fontSize: 12),
                  ),
                ),
              ),
            Expanded(child: widget.child),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: destinations
            .indexOf(GoRouterState.of(c).uri.path)
            .clamp(0, 4),
        onDestinationSelected: (i) => c.go(destinations[i]),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.fitness_center),
            label: 'Entrenar',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            label: 'Comunidad',
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            label: 'Rankings',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

class TitleBlock extends StatelessWidget {
  final String kicker, title;
  final Widget? action;
  const TitleBlock(this.kicker, this.title, {super.key, this.action});
  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 18),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                kicker.toUpperCase(),
                style: const TextStyle(
                  color: lime,
                  fontSize: 11,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(title, style: Theme.of(c).textTheme.headlineLarge),
            ],
          ),
        ),
        if (action != null) action!,
      ],
    ),
  );
}

class Note extends StatelessWidget {
  final String text;
  const Note(this.text, {super.key});
  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      text,
      style: const TextStyle(color: muted, height: 1.4, fontSize: 13),
    ),
  );
}

void snack(BuildContext c, String text) => ScaffoldMessenger.of(c).showSnackBar(
  SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
);
Future<T?> attempt<T>(
  BuildContext c,
  LogState a,
  Future<T> Function() fn,
) async {
  try {
    return await fn();
  } catch (e) {
    if (c.mounted) snack(c, a.api.explain(e));
    return null;
  }
}

String day(dynamic raw) {
  if (raw == null) return '';
  final d = DateTime.parse(raw as String).toLocal();
  String p(int i) => i.toString().padLeft(2, '0');
  return '${p(d.day)}/${p(d.month)} · ${p(d.hour)}:${p(d.minute)}';
}

Future<String?> ask(
  BuildContext c,
  String title, {
  String initial = '',
  int limit = 100,
  bool secret = false,
}) async {
  var value = initial;
  return showDialog<String>(
    context: c,
    builder: (d) => AlertDialog(
      title: Text(title),
      content: TextFormField(
        initialValue: initial,
        onChanged: (v) => value = v,
        obscureText: secret,
        autofocus: true,
        maxLength: limit,
        decoration: const InputDecoration(counterText: ''),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(d),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(d, value.trim()),
          child: const Text('Aceptar'),
        ),
      ],
    ),
  );
}

class NeedAccount extends StatelessWidget {
  final String title;
  const NeedAccount(this.title, {super.key});
  @override
  Widget build(BuildContext c) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      TitleBlock('LIFTLOG', title),
      const Note(
        'Para conectar con otros atletas, inicia sesión en el servidor. Puedes seguir registrando entrenamientos en modo local.',
      ),
      FilledButton(
        onPressed: () => c.push('/cuenta'),
        child: const Text('Iniciar sesión o crear cuenta'),
      ),
    ],
  );
}

class Home extends ConsumerWidget {
  const Home({super.key});
  @override
  Widget build(BuildContext c, WidgetRef ref) {
    final a = ref.watch(stateProvider);
    final now = DateTime.now(),
        done = a.workouts.where((w) => w['ended_at'] != null).toList();
    final week = done
        .where(
          (w) => DateTime.parse(
            w['ended_at'],
          ).isAfter(now.subtract(const Duration(days: 7))),
        )
        .toList();
    double vol = week.fold(0.0, (n, w) => n + volume(w, a.catalog));
    final days = List.generate(7, (i) {
      final d = DateTime(now.year, now.month, now.day - 6 + i);
      return done.where((w) {
        final date = DateTime.parse(w['ended_at']).toLocal();
        return DateUtils.isSameDay(d, date);
      }).length;
    });
    return RefreshIndicator(
      onRefresh: () => a.sync(force: true),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          TitleBlock(
            'LIFTLOG  /  entrenamiento',
            a.onlineAccount ? 'Tu entrenamiento' : 'Tu espacio',
            action: IconButton(
              tooltip: 'Sincronizar ahora',
              onPressed: () => a.sync(force: true),
              icon: const Icon(Icons.sync),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF26331F), surface],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.fitness_center, color: lime, size: 32),
                const SizedBox(height: 18),
                Text(
                  a.active?['name'] ?? 'Entrenamiento libre',
                  style: Theme.of(c).textTheme.headlineMedium,
                ),
                Note(
                  a.active != null
                      ? 'Tu sesión sigue guardada en este teléfono.'
                      : 'Elige tus ejercicios y registra cada serie, incluso sin conexión.',
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () async {
                    final w = await attempt(c, a, () => a.start());
                    if (w != null && c.mounted) c.push('/sesion/${w['id']}');
                  },
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(
                    a.active != null ? 'Reanudar sesión' : 'Empezar sesión',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Últimos 7 días', style: Theme.of(c).textTheme.titleLarge),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${week.length} sesiones  ·  ${mass(vol, a.imperial)}·rep',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 115,
                    child: BarChart(
                      BarChartData(
                        minY: 0,
                        maxY:
                            days
                                .fold<int>(1, (a, b) => a > b ? a : b)
                                .toDouble() +
                            .3,
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (v, _) => Text(
                                '${DateTime(now.year, now.month, now.day - 6 + v.toInt()).day}',
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                        ),
                        barGroups: List.generate(
                          7,
                          (i) => BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: days[i].toDouble(),
                                width: 18,
                                color: lime,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Note(
                    'Barras: sesiones finalizadas por día. Volumen externo = carga × repeticiones, sin calentamientos ni asistencia.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Historial reciente', style: Theme.of(c).textTheme.titleLarge),
          if (done.isEmpty)
            const Note('Tus sesiones aparecerán cuando finalices la primera.'),
          ...done.take(3).map((w) => WorkoutTile(w)),
          const SizedBox(height: 18),
        ],
      ),
    );
  }
}
