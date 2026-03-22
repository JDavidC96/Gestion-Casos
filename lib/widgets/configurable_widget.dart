// lib/widgets/configurable_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/interface_config_provider.dart';

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
    final configProvider = Provider.of<InterfaceConfigProvider>(context);

    final isEnabled = configProvider.currentConfig[feature] ?? true;

    if (isEnabled) {
      return child;
    } else {
      return alternativeChild ?? const SizedBox.shrink();
    }
  }
}