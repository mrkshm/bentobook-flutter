import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bentobook/router.dart';
import 'package:bentobook/core/shared/providers.dart';
import 'package:bentobook/core/theme/theme.dart';
import 'package:bentobook/core/theme/theme_provider.dart';

void main() {
  runApp(
    const ProviderScope(
      child: BentoBookApp(),
    ),
  );
}

class BentoBookApp extends ConsumerStatefulWidget {
  const BentoBookApp({super.key});

  @override
  ConsumerState<BentoBookApp> createState() => _BentoBookAppState();
}

class _BentoBookAppState extends ConsumerState<BentoBookApp> {
  @override
  void initState() {
    super.initState();
    // Initialize auth on app start
    Future.microtask(() => ref.read(authInitControllerProvider).initialize());
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeProvider);
    final colorScheme = ref.watch(colorSchemeProvider);

    return MaterialApp.router(
      title: 'BentoBook',
      theme: AppTheme.light(scheme: colorScheme),
      darkTheme: AppTheme.dark(scheme: colorScheme),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), 
    );
  }
}
