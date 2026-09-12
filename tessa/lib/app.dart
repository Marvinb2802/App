import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application/sound.dart';
import 'ui/screens/home_screen.dart';
import 'ui/theme/tessa_theme.dart';

class TessaApp extends ConsumerStatefulWidget {
  const TessaApp({super.key});

  @override
  ConsumerState<TessaApp> createState() => _TessaAppState();
}

class _TessaAppState extends ConsumerState<TessaApp> {
  bool _tonVorbereitet = false;

  /// Browser lassen Ton nur zu, wenn er das erste Mal aus einer Beruehrung
  /// heraus startet. Deshalb wird beim allerersten Fingerdruck vorbereitet —
  /// egal wo, egal auf welchem Bildschirm.
  void _beiErsterBeruehrung() {
    if (_tonVorbereitet) return;
    _tonVorbereitet = true;
    ref.read(soundProvider.notifier).unlock();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tessa',
      debugShowCheckedModeBanner: false,
      theme: tessaTheme(),
      home: const HomeScreen(),
      builder: (context, child) => Listener(
        onPointerDown: (_) => _beiErsterBeruehrung(),
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
