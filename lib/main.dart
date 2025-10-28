import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import './providers/case_provider.dart';
import './providers/centro_trabajo_provider.dart'; 
import './screens/login_screen.dart';
import './screens/home_screen.dart';
import './screens/centros_trabajo_screen.dart'; 
import './screens/case_list_screen.dart';
import './screens/closed_cases_screen.dart';
import './screens/case_detail_screen.dart';
import './screens/report_screen.dart';

void main() {
  runApp(const GestionCasosApp());
}

class GestionCasosApp extends StatelessWidget {
  const GestionCasosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CaseProvider()),
        ChangeNotifierProvider(create: (_) => CentroTrabajoProvider()), 
      ],
      child: MaterialApp(
        title: 'Gestión de Casos',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        initialRoute: '/login',
        routes: {
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