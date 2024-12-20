import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bentobook/router.dart';
import 'package:bentobook/core/shared/providers.dart';

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

    return MaterialApp.router(
      title: 'BentoBook',
      theme: FlexThemeData.light(
        scheme: FlexScheme.blue,
        textTheme: GoogleFonts.interTextTheme(),
      ),
      darkTheme: FlexThemeData.dark(
        scheme: FlexScheme.blue,
        textTheme: GoogleFonts.interTextTheme(),
      ),
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
