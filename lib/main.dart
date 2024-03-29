import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:intl/intl_standalone.dart';
import 'package:provider/provider.dart';
import 'package:system_theme/system_theme.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'entity/entity.dart';
import 'view/view.dart';
import 'repo/repo.dart';

typedef Localize = String Function(AppLocalizations loc);

class _Route {
  const _Route({
    required this.localize,
    required this.location,
    required this.icon,
    required this.selectedIcon,
  });

  final Icon icon;
  final Icon selectedIcon;
  final Localize localize;
  final String location;
}

final _routes = <_Route>[
  _Route(
    localize: (loc) => loc.schedule,
    location: "/schedule",
    icon: const Icon(Icons.today_outlined),
    selectedIcon: const Icon(Icons.today),
  ),
  _Route(
    localize: (loc) => loc.retakes,
    location: "/retakes",
    icon: const Icon(Icons.accessible_forward),
    selectedIcon: const Icon(Icons.accessible_forward),
  ),
  _Route(
    localize: (loc) => loc.other,
    location: "/timetable",
    icon: const Icon(Icons.list),
    selectedIcon: const Icon(Icons.list),
  ),
];

const _locationIndices = {
  "/schedule": 0,
  "/retakes": 1,
  "/timetable": 2,
  "/settings": 2,
  "/settings/about": 2,
  "/settings/about/license": 2,
};

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final _router = GoRouter(
  initialLocation: "/schedule",
  navigatorKey: _rootNavigatorKey,
  routes: [
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return AppScaffold(state: state, child: child);
      },
      routes: [
        GoRoute(
          path: "/schedule",
          pageBuilder: (context, state) => MaterialPage(
            key: state.pageKey,
            child: const ScheduleView(),
          ),
        ),
        GoRoute(
          path: "/retakes",
          pageBuilder: (context, state) => MaterialPage(
            key: state.pageKey,
            child: const RetakesView(),
          ),
        ),
        GoRoute(
          path: "/timetable",
          pageBuilder: (context, state) => MaterialPage(
            key: state.pageKey,
            child: const OtherView(initialIndex: 0),
          ),
        ),
        GoRoute(
          path: "/settings",
          pageBuilder: (context, state) => MaterialPage(
            key: state.pageKey,
            child: const OtherView(initialIndex: 1),
          ),
          routes: [
            GoRoute(
              path: "about",
              pageBuilder: (context, state) => MaterialPage(
                key: state.pageKey,
                child: const AboutView(),
              ),
              routes: [
                GoRoute(
                  path: "license",
                  pageBuilder: (context, state) => MaterialPage(
                    key: state.pageKey,
                    child: const LicenseView(),
                  )
                )
              ]
            ),
          ]
        ),
      ]
    )
  ]
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemTheme.accentColor.load();
  await findSystemLocale();
  final savedThemeMode = await AdaptiveTheme.getThemeMode();
  final savedLocale = await Preferences.getLocale();
  final savedGroup = await Preferences.getGroup();
  final packageInfo = await PackageInfo.fromPlatform();
  final schedule = await Cache.getSchedule();
  final retakes = await Cache.getRetakes();
  final groups = await Cache.getGroups();
  final timetable = await Cache.getTimeTable();

  runApp(App(
    savedThemeMode: savedThemeMode,
    savedLocale: savedLocale,
    savedGroup: savedGroup,
    packageInfo: packageInfo,
    schedule: schedule,
    retakes: retakes,
    groups: groups,
    timetable: timetable,
  ));
}

class App extends StatelessWidget {
  const App({
    super.key,
    required this.savedThemeMode,
    required this.savedLocale,
    required this.savedGroup,
    required this.packageInfo,
    required this.schedule,
    required this.retakes,
    required this.groups,
    required this.timetable,
  });

  final AdaptiveThemeMode? savedThemeMode;
  final Locale? savedLocale;
  final String? savedGroup;
  final PackageInfo packageInfo;
  final ScheduleEntity? schedule;
  final RetakesEntity? retakes;
  final GroupsEntity? groups;
  final TimeTableEntity? timetable;

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return SystemThemeBuilder(
      builder: (context, accent) => AdaptiveTheme(
        light: ThemeData(
          brightness: Brightness.light,
          colorScheme: ColorScheme.fromSeed(seedColor: accent.accent, brightness: Brightness.light),
          useMaterial3: true,
        ),
        dark: ThemeData(
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(seedColor: accent.accent, brightness: Brightness.dark),
          useMaterial3: true,
        ),
        initial: savedThemeMode ?? AdaptiveThemeMode.system,
        builder: (light, dark) => MultiProvider(
          providers: [
            Provider(create: (_) => AppInfoProvider(packageInfo: packageInfo)),
            ChangeNotifierProvider(create: (_) => PreferencesProvider(
              locale: savedLocale ?? Preferences.getDefaultLocale(),
              group: savedGroup ?? ""
            )),
            ChangeNotifierProvider(create: (_) => CacheProvider(
              schedule: schedule,
              retakes: retakes,
              groups: groups,
              timetable: timetable,
            )),
            Provider(
              create: (_) => GrpcProvider(),
              dispose: (_, grpc) async => await grpc.close(),
            ),
          ],
          builder: (context, child) => MaterialApp.router(
            theme: light,
            darkTheme: dark,
            routerConfig: _router,
            locale: Provider.of<PreferencesProvider>(context).locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        )
      )
    );
  }
}

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.state,
    required this.child,
  });

  final GoRouterState state;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final location = state.uri.toString();
    final currentRouteIdx = _locationIndices[location]!;
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (int index) {
          GoRouter.of(context).go(_routes[index].location);
        },
        selectedIndex: currentRouteIdx,
        destinations: [
          for (final route in _routes) NavigationDestination(
            label: route.localize(loc),
            icon: route.icon,
            selectedIcon: route.selectedIcon,
          )
        ],
      ),
    );
  }
}
