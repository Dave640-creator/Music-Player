import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/media_provider.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Status bar style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
            systemNavigationBarColor: AppTheme.deep,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Background audio
  /* await JustAudioBackground.init(
    androidNotificationChannelId: 'com.smartmusicplayer.channel.audio',
    androidNotificationChannelName: 'Smart Music Player',
    androidNotificationOngoing: true,
    androidStopForegroundOnPause: true,
  );
*/
  runApp(const SmartMusicPlayerApp());
}

class SmartMusicPlayerApp extends StatelessWidget {
  const SmartMusicPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
        return ChangeNotifierProvider(
      create: (_) => MediaProvider(),
      child: MaterialApp(
        title: 'Mosaic Player',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.buildTheme(brightness: Brightness.dark),
        home: const MosaicHomePage(),
      ),
    );
  }
}

/// Placeholder home for the Mosaic Player shell.
/// The prior agent deleted the DISCOVER/LIBRARY/PLAYER/ME screens during the
/// rebuild; a minimal home is sufficient to boot the app while those screens
/// are reintroduced. The media sheets in this turn are standalone and ready to
/// be wired into those screens.
class MosaicHomePage extends StatelessWidget {
  const MosaicHomePage({super.key});

  @override
  Widget build(BuildContext context) {
        return const Scaffold(
      body: Center(child: Text('Mosaic Player')),
    );
  }
}
