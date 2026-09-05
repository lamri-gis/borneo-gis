import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'providers/gps_provider.dart';
import 'providers/map_provider.dart';
import 'providers/track_provider.dart';
import 'screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const BorneoGISNavigator());
}

class BorneoGISNavigator extends StatelessWidget {
  const BorneoGISNavigator({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GpsProvider()),
        ChangeNotifierProvider(create: (_) => MapProvider()),
        ChangeNotifierProvider(create: (_) => TrackProvider()),
      ],
      child: MaterialApp(
        title: 'BorneoGIS Navigator',
        theme: AppTheme.dark,
        home: const MainScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
