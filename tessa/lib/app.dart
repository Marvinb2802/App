import 'package:flutter/material.dart';

import 'ui/screens/home_screen.dart';
import 'ui/theme/tessa_theme.dart';

class TessaApp extends StatelessWidget {
  const TessaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tessa',
      debugShowCheckedModeBanner: false,
      theme: tessaTheme(),
      home: const HomeScreen(),
    );
  }
}
