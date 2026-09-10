import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tessa/app.dart';
import 'package:tessa/application/providers.dart';
import 'package:tessa/application/sound.dart';
import 'package:tessa/ui/screens/home_screen.dart';

import '../support/fake_sound.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('die erste Beruehrung bereitet die Toene vor', (tester) async {
    final sound = RecordingOutput();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          soundOutputProvider.overrideWithValue(sound),
          seedSourceProvider.overrideWithValue(() => 1),
        ],
        child: const TessaApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(sound.unlocks, 0, reason: 'vor der ersten Beruehrung noch nicht');

    // Irgendwo hintippen genuegt — im Browser zaehlt genau das als Freigabe.
    await tester.tapAt(tester.getCenter(find.byType(HomeScreen)));
    await tester.pumpAndSettle();

    expect(sound.unlocks, 1);

    // Weitere Beruehrungen bereiten nicht erneut vor.
    await tester.tapAt(tester.getCenter(find.byType(HomeScreen)));
    await tester.pumpAndSettle();
    expect(sound.unlocks, 1);
  });
}
