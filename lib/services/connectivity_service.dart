// lib/services/connectivity_service.dart
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final _connectivity = Connectivity();
  final _controller = StreamController<bool>.broadcast();

  bool _isOnline = true;

  /// Estado actual de conectividad.
  bool get isOnline => _isOnline;

  /// Stream que emite `true` cuando hay red y `false` cuando no.
  Stream<bool> get onConnectivityChanged => _controller.stream;

  /// Inicializar: verificar estado actual y suscribirse a cambios.
  /// Llamar una sola vez en main() antes de runApp().
  Future<void> init() async {
    // Estado inicial
    final results = await _connectivity.checkConnectivity();
    _isOnline = _hasConnection(results);

    // Escuchar cambios futuros
    _connectivity.onConnectivityChanged.listen((results) {
      final online = _hasConnection(results);
      if (online != _isOnline) {
        _isOnline = online;
        _controller.add(_isOnline);
      }
    });
  }

  bool _hasConnection(List<ConnectivityResult> results) {
    return results.any((r) => r != ConnectivityResult.none);
  }

  void dispose() {
    _controller.close();
  }
}