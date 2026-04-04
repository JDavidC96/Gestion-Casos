// lib/providers/connectivity_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/connectivity_service.dart';
import '../services/sync_service.dart';
import '../services/offline_case_service.dart';

class ConnectivityProvider with ChangeNotifier {
  bool _isOnline = true;
  int _pendingCount = 0;
  StreamSubscription<bool>? _connSub;
  StreamSubscription<void>? _syncSub;
  StreamSubscription<List<Map<String, dynamic>>>? _offlineSub;

  bool get isOnline => _isOnline;

  /// Cantidad de casos offline pendientes de sincronizar.
  int get pendingCount => _pendingCount;

  bool get hasPending => _pendingCount > 0;

  void init() {
    // Estado inicial
    _isOnline = ConnectivityService.instance.isOnline;
    _pendingCount = OfflineCaseService.instance.getPending().length;

    // Escuchar cambios de conectividad
    _connSub = ConnectivityService.instance.onConnectivityChanged.listen((online) {
      if (_isOnline != online) {
        _isOnline = online;
        notifyListeners();
      }
    });

    // Escuchar sincronizaciones completadas
    _syncSub = SyncService.instance.onSyncDone.listen((_) {
      _pendingCount = OfflineCaseService.instance.getPending().length;
      notifyListeners();
    });

    // Escuchar cambios en casos offline
    _offlineSub = OfflineCaseService.instance.casesStream.listen((pending) {
      _pendingCount = pending.length;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _syncSub?.cancel();
    _offlineSub?.cancel();
    super.dispose();
  }
}