// lib/services/dashboard_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo con todas las estadísticas del sistema.
class DashboardStats {
  final int totalGrupos;
  final int totalUsuarios;
  final int totalEmpresas;
  final int totalCentros;
  final int totalCasos;
  final int casosAbiertos;
  final int casosCerrados;
  final int admins;
  final int superInspectores;
  final int inspectores;
  final int casosUltimos7Dias;
  final int casosUltimos30Dias;
  final int casosCerradosUltimos30Dias;
  final List<GrupoStats> grupos;
  final Map<String, int> casosPorTipoRiesgo;
  final Map<String, int> casosPorNivelPeligro;
  final List<InspectorStats> topInspectores;
  final List<MesStats> tendenciaMensual;
  final double? tiempoPromedioResolucionHoras;

  const DashboardStats({
    required this.totalGrupos, required this.totalUsuarios,
    required this.totalEmpresas, required this.totalCentros,
    required this.totalCasos, required this.casosAbiertos,
    required this.casosCerrados, required this.admins,
    required this.superInspectores, required this.inspectores,
    required this.casosUltimos7Dias, required this.casosUltimos30Dias,
    required this.casosCerradosUltimos30Dias, required this.grupos,
    required this.casosPorTipoRiesgo, required this.casosPorNivelPeligro,
    required this.topInspectores, required this.tendenciaMensual,
    this.tiempoPromedioResolucionHoras,
  });
}

class GrupoStats {
  final String id, nombre;
  final int usuarios, empresas, centros, casosAbiertos, casosCerrados;
  final DateTime? ultimaActividad;
  const GrupoStats({required this.id, required this.nombre, required this.usuarios,
    required this.empresas, required this.centros, required this.casosAbiertos,
    required this.casosCerrados, this.ultimaActividad});
  int get totalCasos => casosAbiertos + casosCerrados;
}

class InspectorStats {
  final String nombre, grupoNombre;
  final int casosCreados, casosCerrados;
  const InspectorStats({required this.nombre, required this.grupoNombre,
    required this.casosCreados, required this.casosCerrados});
}

class MesStats {
  final String etiqueta;
  final int creados, cerrados;
  const MesStats({required this.etiqueta, required this.creados, required this.cerrados});
}

class DashboardService {
  static final _db = FirebaseFirestore.instance;

  static Future<DashboardStats> cargarEstadisticas() async {
    final gruposSnap = await _db.collection('grupos').get();
    final usersSnap = await _db.collection('users').get();

    int admins = 0, superInsp = 0, insp = 0;
    final usersByGroup = <String, int>{};
    for (final doc in usersSnap.docs) {
      final d = doc.data();
      final role = d['role'] as String? ?? '';
      final gid = d['grupoId'] as String? ?? '';
      if (role == 'admin') admins++;
      else if (role == 'superinspector') superInsp++;
      else if (role == 'inspector') insp++;
      if (gid.isNotEmpty) usersByGroup[gid] = (usersByGroup[gid] ?? 0) + 1;
    }

    final now = DateTime.now();
    final hace7 = now.subtract(const Duration(days: 7));
    final hace30 = now.subtract(const Duration(days: 30));
    int tEmpresas = 0, tCentros = 0, tCasos = 0, abiertos = 0, cerrados = 0;
    int ult7 = 0, ult30 = 0, cerr30 = 0;
    final porTipo = <String, int>{};
    final porNivel = <String, int>{};
    final inspMap = <String, _Acc>{};
    final tendMap = <String, _MesAcc>{};
    double sumaH = 0; int cConT = 0;
    final grupoList = <GrupoStats>[];

    for (int i = 5; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i, 1);
      tendMap['${m.year}-${m.month.toString().padLeft(2, '0')}'] = _MesAcc(mes: m);
    }

    for (final gDoc in gruposSnap.docs) {
      final gId = gDoc.id;
      final gNombre = (gDoc.data())['nombre'] as String? ?? 'Sin nombre';
      int gE = 0, gC = 0, gA = 0, gCe = 0;
      DateTime? gUlt;

      final empSnap = await _db.collection('grupos').doc(gId).collection('empresas').get();
      gE = empSnap.docs.length; tEmpresas += gE;

      for (final eDoc in empSnap.docs) {
        final cenSnap = await _db.collection('grupos').doc(gId)
            .collection('empresas').doc(eDoc.id).collection('centros_trabajo').get();
        gC += cenSnap.docs.length; tCentros += cenSnap.docs.length;

        for (final cDoc in cenSnap.docs) {
          final casSnap = await _db.collection('grupos').doc(gId)
              .collection('empresas').doc(eDoc.id)
              .collection('centros_trabajo').doc(cDoc.id)
              .collection('casos').get();

          for (final caso in casSnap.docs) {
            final d = caso.data(); tCasos++;
            final esCerrado = d['cerrado'] == true;
            if (esCerrado) { cerrados++; gCe++; } else { abiertos++; gA++; }

            final fc = (d['fechaCreacion'] as Timestamp?)?.toDate();
            if (fc != null) {
              if (fc.isAfter(hace7)) ult7++;
              if (fc.isAfter(hace30)) ult30++;
              final mk = '${fc.year}-${fc.month.toString().padLeft(2, '0')}';
              if (tendMap.containsKey(mk)) tendMap[mk]!.creados++;
              if (gUlt == null || fc.isAfter(gUlt)) gUlt = fc;
            }

            if (esCerrado) {
              final fci = (d['fechaCierre'] as Timestamp?)?.toDate();
              if (fci != null) {
                if (fci.isAfter(hace30)) cerr30++;
                final mkc = '${fci.year}-${fci.month.toString().padLeft(2, '0')}';
                if (tendMap.containsKey(mkc)) tendMap[mkc]!.cerrados++;
                if (fc != null) { sumaH += fci.difference(fc).inMinutes / 60.0; cConT++; }
              }
            }

            final tipo = d['tipoRiesgo'] as String? ?? 'Otro';
            porTipo[tipo] = (porTipo[tipo] ?? 0) + 1;

            final ea = d['estadoAbierto'] as Map<String, dynamic>?;
            final niv = ea?['nivelPeligro'] as String? ?? d['nivelPeligro'] as String? ?? '';
            if (niv.isNotEmpty) porNivel[niv] = (porNivel[niv] ?? 0) + 1;

            final iNom = ea?['usuarioNombre'] as String? ?? d['usuarioNombre'] as String?;
            if (iNom != null && iNom.isNotEmpty) {
              final a = inspMap.putIfAbsent(iNom, () => _Acc(n: iNom, g: gNombre));
              a.c++; if (esCerrado) a.ce++;
            }
          }
        }
      }

      grupoList.add(GrupoStats(id: gId, nombre: gNombre, usuarios: usersByGroup[gId] ?? 0,
          empresas: gE, centros: gC, casosAbiertos: gA, casosCerrados: gCe, ultimaActividad: gUlt));
    }

    final topInsp = inspMap.values.toList()..sort((a, b) => b.c.compareTo(a.c));
    const mc = ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
    final tend = tendMap.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    grupoList.sort((a, b) => b.totalCasos.compareTo(a.totalCasos));

    return DashboardStats(
      totalGrupos: gruposSnap.docs.length, totalUsuarios: usersSnap.docs.length,
      totalEmpresas: tEmpresas, totalCentros: tCentros, totalCasos: tCasos,
      casosAbiertos: abiertos, casosCerrados: cerrados,
      admins: admins, superInspectores: superInsp, inspectores: insp,
      casosUltimos7Dias: ult7, casosUltimos30Dias: ult30,
      casosCerradosUltimos30Dias: cerr30, grupos: grupoList,
      casosPorTipoRiesgo: porTipo, casosPorNivelPeligro: porNivel,
      topInspectores: topInsp.take(10).map((a) => InspectorStats(
          nombre: a.n, grupoNombre: a.g, casosCreados: a.c, casosCerrados: a.ce)).toList(),
      tendenciaMensual: tend.map((e) => MesStats(
          etiqueta: mc[e.value.mes.month - 1], creados: e.value.creados, cerrados: e.value.cerrados)).toList(),
      tiempoPromedioResolucionHoras: cConT > 0 ? sumaH / cConT : null,
    );
  }
}

class _Acc { final String n, g; int c = 0, ce = 0; _Acc({required this.n, required this.g}); }
class _MesAcc { final DateTime mes; int creados = 0, cerrados = 0; _MesAcc({required this.mes}); }