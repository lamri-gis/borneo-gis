import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'providers/gps_provider.dart';
import 'providers/map_provider.dart';
import 'providers/track_provider.dart';
import 'providers/layer_provider.dart';
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
        ChangeNotifierProvider(create: (_) => MapProvider()),
        ChangeNotifierProvider(create: (_) => TrackProvider()),
        ChangeNotifierProvider(create: (_) => LayerProvider()),
        ChangeNotifierProvider(create: (_) => GpsProvider()),
      ],
      child: const _AppInit(),
    );
  }
}

// Inisialisasi setelah semua provider tersedia
class _AppInit extends StatefulWidget {
  const _AppInit();

  @override
  State<_AppInit> createState() => _AppInitState();
}

class _AppInitState extends State<_AppInit> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final gps = context.read<GpsProvider>();
      final layer = context.read<LayerProvider>();
      // Set LayerProvider sekali saja -- tidak pakai proxy
      gps.setLayerProvider(layer);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BorneoGIS Navigator',
      theme: AppTheme.dark,
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
