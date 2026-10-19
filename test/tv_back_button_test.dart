import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ecohub_android/components/player/video_player_widget.dart';

void main() {
  testWidgets(
    'TV fullscreen back button exits its playback route instead of toggling fullscreen',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      var fullscreenChanges = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (pageContext) => Scaffold(
                      body: VideoPlayerWidget(
                        videoUrl: '',
                        isFull: true,
                        backExitsPage: true,
                        onBack: () => Navigator.pop(pageContext),
                        onFullscreenChange: (_, {bool isPortrait = false}) =>
                            fullscreenChanges++,
                      ),
                    ),
                  ),
                ),
                child: const Text('home'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('home'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded).first);
      await tester.pumpAndSettle();
      expect(find.byType(VideoPlayerWidget), findsNothing);
      expect(find.text('home'), findsOneWidget);
      expect(fullscreenChanges, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
