import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'screens/assistant_screen.dart';
import 'screens/form_screen.dart';
import 'screens/history_screen.dart';
import 'screens/report_screen.dart';
import 'screens/what_if_screen.dart';
import 'services/api_client.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Ignore missing env files in test/dev fallbacks.
  }
  runApp(const HeartAnalysisApp());
}

class HeartAnalysisApp extends StatefulWidget {
  const HeartAnalysisApp({super.key});

  @override
  State<HeartAnalysisApp> createState() => _HeartAnalysisAppState();
}

class _HeartAnalysisAppState extends State<HeartAnalysisApp> {
  late final ApiClient _apiClient;
  late final AppState _appState;

  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient();
    _appState = AppState();
  }

  @override
  void dispose() {
    _apiClient.dispose();
    _appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppState>.value(
      value: _appState,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'HeartAnalysis',
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF0E7490),
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: const Color(0xFFF4F7FB),
          cardTheme: CardThemeData(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFFE5EAF0)),
            ),
          ),
          inputDecorationTheme: const InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(),
          ),
        ),
        home: _HomeShell(apiClient: _apiClient, appState: _appState),
      ),
    );
  }
}

class _HomeShell extends StatefulWidget {
  const _HomeShell({required this.apiClient, required this.appState});

  final ApiClient apiClient;
  final AppState appState;

  @override
  State<_HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<_HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      FormScreen(
        apiClient: widget.apiClient,
        appState: widget.appState,
        onPredictionCreated: () => setState(() => _index = 1),
      ),
      ReportScreen(appState: widget.appState, apiClient: widget.apiClient),
      HistoryScreen(apiClient: widget.apiClient, appState: widget.appState),
      WhatIfScreen(apiClient: widget.apiClient, appState: widget.appState),
      AssistantScreen(appState: widget.appState, apiClient: widget.apiClient),
    ];

    final destinations = const [
      NavigationDestination(icon: Icon(Icons.edit_note), label: 'Input'),
      NavigationDestination(icon: Icon(Icons.analytics_outlined), label: 'Report'),
      NavigationDestination(icon: Icon(Icons.history), label: 'History'),
      NavigationDestination(icon: Icon(Icons.tune), label: 'What-If'),
      NavigationDestination(icon: Icon(Icons.assistant_outlined), label: 'Assistant'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;

        if (wide) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('HeartAnalysis'),
              centerTitle: false,
            ),
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: (value) => setState(() => _index = value),
                  labelType: NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.edit_note),
                      label: Text('Input'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.analytics_outlined),
                      label: Text('Report'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.history),
                      label: Text('History'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.tune),
                      label: Text('What-If'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.assistant_outlined),
                      label: Text('Assistant'),
                    ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: tabs[_index]),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('HeartAnalysis'),
            centerTitle: false,
          ),
          body: tabs[_index],
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            destinations: destinations,
            onDestinationSelected: (value) => setState(() => _index = value),
          ),
        );
      },
    );
  }
}
