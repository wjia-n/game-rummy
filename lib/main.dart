import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/splash_screen.dart';
import 'services/audio_service.dart';
import 'services/settings_service.dart';
import 'theme/felt_table.dart';
import 'theme/felt_themes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  final settings = RummySettings();
  await settings.load();
  final audio = RummyAudio();
  audio.configure(
    musicOn: settings.musicOn,
    sfxOn: settings.sfxOn,
    volume: settings.volume,
  );
  runApp(RummyApp(settings: settings, audio: audio));
}

class RummyApp extends StatefulWidget {
  final RummySettings settings;
  final RummyAudio audio;
  const RummyApp({super.key, required this.settings, required this.audio});

  @override
  State<RummyApp> createState() => _RummyAppState();
}

class _RummyAppState extends State<RummyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.audio.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause (not stop) on interruption so music resumes exactly where it
    // left off; game screens additionally freeze their engines.
    if (state == AppLifecycleState.paused) {
      widget.audio.onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      widget.audio.onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (_, _) => MaterialApp(
        title: 'Rummy',
        debugShowCheckedModeBanner: false,
        theme:
            Felt.theme(FeltThemes.byId(widget.settings.themeId, custom: widget.settings.customTheme)),
        home:
            SplashScreen(audio: widget.audio, settings: widget.settings),
      ),
    );
  }
}
