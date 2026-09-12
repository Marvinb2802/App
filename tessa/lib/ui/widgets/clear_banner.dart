import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../domain/model/game_state.dart';
import '../format.dart';
import 'clear_effects.dart';

/// Das grosse Wort mitten auf dem Bild, wenn Linien fallen: „DOPPEL", die
/// Punkte des Zuges und — wenn sie laeuft — die Combo.
///
/// Es faehrt mit Ueberschwingen auf, schwebt nach oben und verschwindet.
class ClearBanner extends ConsumerStatefulWidget {
  const ClearBanner({super.key});

  static const Duration duration = Duration(milliseconds: 900);

  @override
  ConsumerState<ClearBanner> createState() => _ClearBannerState();
}

class _ClearBannerState extends ConsumerState<ClearBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: ClearBanner.duration,
  )..addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _move = null);
      }
    });

  MoveOutcome? _move;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onStateChanged(GameState? previous, GameState next) {
    final move = neuerZug(previous, next);
    if (move == null || !move.didClear) return;
    setState(() => _move = move);
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(gameControllerProvider, _onStateChanged);

    final move = _move;
    if (move == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final farbe = _farbe(move.clearedLines);

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          // Auffahren mit Ueberschwingen, dann nach oben wegschweben.
          final auf = Curves.easeOutBack.transform((t / 0.22).clamp(0.0, 1.0));
          final weg = Curves.easeInCubic.transform(
              ((t - 0.55) / 0.45).clamp(0.0, 1.0));

          return Opacity(
            opacity: 1 - weg,
            child: Transform.translate(
              offset: Offset(0, -60 * weg),
              child: Transform.scale(
                scale: 0.4 + 0.6 * auf + 0.08 * weg,
                child: Column(
                  key: const Key('clear-banner'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      raeumWort(move.clearedLines),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: Colors.white,
                        shadows: [
                          Shadow(color: farbe, blurRadius: 24),
                          Shadow(color: farbe, blurRadius: 48),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      move.appliedCombo > 1
                          ? '+${zahl(move.points)}  ·  COMBO ×${move.appliedCombo}'
                          : '+${zahl(move.points)}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: farbe,
                        shadows: const [
                          Shadow(color: Colors.black54, blurRadius: 8),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Je mehr Linien, desto heisser die Farbe.
  Color _farbe(int linien) => switch (linien) {
        1 => const Color(0xFF6C8BFF),
        2 => const Color(0xFF3DD6A0),
        3 => const Color(0xFFFFC44D),
        _ => const Color(0xFFFF6B57),
      };
}
