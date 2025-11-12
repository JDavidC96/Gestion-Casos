// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import './providers/auth_provider.dart';
import './providers/case_provider.dart';
import './providers/centro_trabajo_provider.dart';
import './screens/splash_screen.dart';
import './screens/login_screen.dart';
import './screens/setup_super_user_screen.dart';
import './screens/home_screen.dart';
import './screens/centros_trabajo_screen.dart';
import './screens/case_list_screen.dart';
import './screens/case_detail_screen.dart';
import './screens/report_screen.dart';
import './screens/closed_cases_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const GestionCasosApp());
}



class GestionCasosApp extends StatelessWidget {
  const GestionCasosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CaseProvider()),
        ChangeNotifierProvider(create: (_) => CentroTrabajoProvider()),
      ],
      child: MaterialApp(
        title: 'Gestión de Casos',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        initialRoute: '/splash',
        routes: {
          '/splash': (_) => const SplashScreen(),
          '/setup': (_) => const SetupSuperUserScreen(),
          '/login': (_) => const LoginScreen(),
          '/home': (_) => const HomeScreen(),
          '/centros': (_) => const CentrosTrabajoScreen(),
          '/cases': (_) => const CaseListScreen(),
          '/closedCases': (context) => const ClosedCasesScreen(),
          '/caseDetail': (_) => const CaseDetailScreen(),
          '/report': (_) => const ReportScreen(),
        },
      ),
    );
  }
}