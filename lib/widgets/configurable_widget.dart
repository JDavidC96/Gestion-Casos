// lib/widgets/configurable_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/user_service.dart';

class ConfigurableWidget extends StatelessWidget {
  final String feature;
  final Widget child;
  final Widget? alternativeChild;

  const ConfigurableWidget({
    super.key,
    required this.feature,
    required this.child,
    this.alternativeChild,
  });

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    
    return FutureBuilder<Map<String, dynamic>?>(
      future: UserService.getConfigInterfaz(authProvider.grupoId ?? ''),
      builder: (context, snapshot) {
        final config = snapshot.data;
        final isEnabled = config?[feature] ?? true;
        
        if (isEnabled) {
          return child;
        } else {
          return alternativeChild ?? const SizedBox.shrink();
        }
      },
    );
  }
}