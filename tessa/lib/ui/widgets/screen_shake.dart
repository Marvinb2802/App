import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../domain/model/game_state.dart';
import 'clear_effects.dart';

/// Ruettelt sein Kind, wenn Linien fallen — je mehr, desto kraeftiger.
///
/// Das Ruetteln klingt aus (die Amplitude faellt linear), damit es sich wie ein
/// Schlag anfuehlt und nicht wie ein Wackelkontakt. Wer im System „Bewegung
/// reduzieren" eingeschaltet hat, bekommt es gar nicht zu sehen.
class ScreenShake extends ConsumerStatefulWidget {
  const ScreenShake({super.key, required this.child});

  final Widget child;

  static const Duration duration = Duration(milliseconds: 380);

  @override
  ConsumerState<ScreenShake> createState() => _ScreenShakeState();
}

class _ScreenShakeState extends ConsumerState<ScreenShake>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: ScreenShake.duration,
  );

  /// Wie weit es beim laufenden Ruettler ausschlaegt.
  double _weite = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onStateChanged(GameState? previous, GameState next) {
    final move = neuerZug(previous, next);
    if (move == null || !move.didClear) return;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;

    _weite = ruettelWeite(move.clearedLines);
    if (_weite <= 0) return;
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(gameControllerProvider, _onStateChanged);

    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = _controller.value;
        // Der Transform steht immer da, auch in Ruhe. Wuerde er nur beim
        // Ruetteln eingehaengt, aenderte sich die Form des Widget-Baums — und
        // Flutter baut darunter alles neu auf, samt Zustand des Bretts. Das
        // hat einmal mitten im Zug die Raeum-Animation verschluckt.
        final abklang = t == 0 || t == 1 ? 0.0 : _weite * (1 - t);
        // Zwei unterschiedliche Frequenzen: sonst sieht es aus wie ein Pendel.
        return Transform.translate(
          key: const Key('screen-shake'),
          offset: Offset(
            math.sin(t * math.pi * 7) * abklang,
            math.cos(t * math.pi * 9) * abklang * 0.6,
          ),
          child: child,
        );
      },
    );
  }
}
