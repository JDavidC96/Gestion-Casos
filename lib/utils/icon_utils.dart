// utils/icon_utils.dart
import 'package:flutter/material.dart';

class IconUtils {
  // Método existente para tipos de centros
  static IconData getIconPorTipo(String tipo) {
    switch (tipo) {
      case "Sede Principal":
        return Icons.corporate_fare;
      case "Sucursal":
        return Icons.business;
      case "Planta de Producción":
        return Icons.factory;
      case "Bodega":
        return Icons.warehouse_rounded;
      case "Oficina Regional":
        return Icons.apartment;
      case "Almacén":
        return Icons.warehouse;
      case "Punto de Venta":
        return Icons.store;
      default:
        return Icons.place;
    }
  }

  // Nuevo método para iconos de empresas
  static const Map<String, IconData> iconMapEmpresas = {
    'business': Icons.business,
    'store': Icons.store,
    'shopping_cart': Icons.shopping_cart,
    'apartment': Icons.apartment,
    'corporate_fare': Icons.corporate_fare,
    'factory': Icons.factory,
    'local_shipping': Icons.local_shipping,
    'warehouse': Icons.warehouse,
    'account_balance': Icons.account_balance,
    'school': Icons.school,
    'local_hospital': Icons.local_hospital,
    'restaurant': Icons.restaurant,
    'hotel': Icons.hotel,
    'construction': Icons.construction,
  };

  static IconData getIconEmpresa(String iconName) {
    return iconMapEmpresas[iconName] ?? Icons.business;
  }

  static String getIconName(IconData icon) {
    return iconMapEmpresas.entries
        .firstWhere(
          (entry) => entry.value.codePoint == icon.codePoint,
          orElse: () => MapEntry('business', Icons.business),
        )
        .key;
  }
}