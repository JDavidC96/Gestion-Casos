// utils/icon_utils.dart
import 'package:flutter/material.dart';

class IconUtils {
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
}