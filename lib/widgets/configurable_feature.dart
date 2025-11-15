// lib/widgets/configurable_feature.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/interface_config_provider.dart';
import '../services/interface_config_service.dart';

class ConfigurableFeature extends StatelessWidget {
  final String feature;
  final Widget child;
  final Widget? alternativeChild;
  final bool defaultVisibility;

  const ConfigurableFeature({
    super.key,
    required this.feature,
    required this.child,
    this.alternativeChild,
    this.defaultVisibility = true,
  });

  @override
  Widget build(BuildContext context) {
    final configProvider = Provider.of<InterfaceConfigProvider>(context);
    
    final isEnabled = configProvider.currentConfig[feature] ?? defaultVisibility;
    
    if (isEnabled) {
      return child;
    } else {
      return alternativeChild ?? const SizedBox.shrink();
    }
  }
}

// Widget para características que requieren grupo específico
class GroupConfigurableFeature extends StatelessWidget {
  final String grupoId;
  final String feature;
  final Widget child;
  final Widget? alternativeChild;
  final bool defaultVisibility;

  const GroupConfigurableFeature({
    super.key,
    required this.grupoId,
    required this.feature,
    required this.child,
    this.alternativeChild,
    this.defaultVisibility = true,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: InterfaceConfigService.isFeatureEnabled(grupoId, feature),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }
        
        final isEnabled = snapshot.data ?? defaultVisibility;
        
        if (isEnabled) {
          return child;
        } else {
          return alternativeChild ?? const SizedBox.shrink();
        }
      },
    );
  }
}