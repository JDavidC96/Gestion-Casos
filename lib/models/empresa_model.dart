import 'package:flutter/material.dart';

class Empresa {
  final String id;
  final String nombre;
  final String nit; 
  final IconData icon;

  Empresa({
    required this.id,
    required this.nombre,
    required this.nit, 
    required this.icon,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'nit': nit,
      'icon': icon.codePoint,
    };
  }

  factory Empresa.fromMap(Map<String, dynamic> map) {
    return Empresa(
      id: map['id'],
      nombre: map['nombre'],
      nit: map['nit'], 
      icon: IconData(map['icon'], fontFamily: 'MaterialIcons'),
    );
  }
}