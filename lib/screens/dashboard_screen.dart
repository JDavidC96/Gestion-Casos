// lib/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/dashboard_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardStats? _stats;
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    setState(() { _loading = true; _error = null; });
    try {
      final stats = await DashboardService.cargarEstadisticas();
      if (mounted) setState(() { _stats = stats; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      CircularProgressIndicator(color: Colors.white), SizedBox(height: 16),
      Text('Cargando estadísticas...', style: TextStyle(color: Colors.white70)),
    ]));
    if (_error != null) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.error_outline, size: 64, color: Colors.white70), const SizedBox(height: 16),
      Text('Error: $_error', style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
      const SizedBox(height: 16),
      ElevatedButton.icon(onPressed: _cargar, icon: const Icon(Icons.refresh), label: const Text('Reintentar')),
    ]));

    final s = _stats!;
    return RefreshIndicator(onRefresh: _cargar, child: ListView(padding: const EdgeInsets.all(16), children: [
      _buildKpiRow(s), const SizedBox(height: 16),
      _sec('Actividad reciente'), _buildActividadCards(s), const SizedBox(height: 20),
      _sec('Estado de casos'), _pie([_PE('Abiertos', s.casosAbiertos, Colors.orange), _PE('Cerrados', s.casosCerrados, Colors.green)]), const SizedBox(height: 20),
      _sec('Tendencia mensual (6 meses)'), _buildBarTendencia(s), const SizedBox(height: 20),
      _sec('Distribución por tipo de riesgo'), _buildPieTipo(s), const SizedBox(height: 20),
      _sec('Distribución por nivel de peligro'), _buildPieNivel(s), const SizedBox(height: 20),
      if (s.grupos.any((g) => g.totalCasos > 0)) ...[_sec('Casos por grupo'), _buildBarGrupos(s), const SizedBox(height: 20)],
      if (s.topInspectores.isNotEmpty) ...[_sec('Top inspectores'), _buildTopInsp(s), const SizedBox(height: 20)],
      _sec('Detalle por grupo'), _buildTablaGrupos(s), const SizedBox(height: 20),
      _sec('Usuarios por rol'), _pie([_PE('Admins', s.admins, Colors.purple), _PE('Super Insp.', s.superInspectores, Colors.blue), _PE('Inspectores', s.inspectores, Colors.teal)]),
      const SizedBox(height: 40),
    ]));
  }

  Widget _buildKpiRow(DashboardStats s) => Wrap(spacing: 10, runSpacing: 10, children: [
    _kpi(Icons.group, 'Grupos', '${s.totalGrupos}', Colors.purple),
    _kpi(Icons.people, 'Usuarios', '${s.totalUsuarios}', Colors.blue),
    _kpi(Icons.business, 'Empresas', '${s.totalEmpresas}', Colors.teal),
    _kpi(Icons.location_city, 'Centros', '${s.totalCentros}', Colors.indigo),
    _kpi(Icons.assignment, 'Casos', '${s.totalCasos}', Colors.orange),
    if (s.tiempoPromedioResolucionHoras != null)
      _kpi(Icons.timer, 'Prom. resolución', s.tiempoPromedioResolucionHoras! < 24
          ? '${s.tiempoPromedioResolucionHoras!.toStringAsFixed(1)}h'
          : '${(s.tiempoPromedioResolucionHoras! / 24).toStringAsFixed(1)}d', Colors.green),
  ]);

  Widget _kpi(IconData ic, String label, String val, Color c) => Container(
    width: 105, padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
    decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(14), border: Border.all(color: c.withOpacity(0.4))),
    child: Column(children: [
      Icon(ic, color: c, size: 22), const SizedBox(height: 6),
      Text(val, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: c)),
      const SizedBox(height: 2), Text(label, style: const TextStyle(fontSize: 10, color: Colors.white70), textAlign: TextAlign.center),
    ]),
  );

  Widget _buildActividadCards(DashboardStats s) => Row(children: [
    Expanded(child: _act('Últimos 7 días', '${s.casosUltimos7Dias}', 'creados', Colors.blue)),
    const SizedBox(width: 10),
    Expanded(child: _act('Últimos 30 días', '${s.casosUltimos30Dias}', 'creados', Colors.orange)),
    const SizedBox(width: 10),
    Expanded(child: _act('Cerrados', '${s.casosCerradosUltimos30Dias}', 'últimos 30d', Colors.green)),
  ]);

  Widget _act(String t, String v, String sub, Color c) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(14), border: Border.all(color: c.withOpacity(0.3))),
    child: Column(children: [
      Text(v, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: c)),
      Text(sub, style: TextStyle(fontSize: 11, color: c.withOpacity(0.8))),
      const SizedBox(height: 4), Text(t, style: const TextStyle(fontSize: 10, color: Colors.white60), textAlign: TextAlign.center),
    ]),
  );

  Widget _pie(List<_PE> entries, {bool legendBelow = false}) {
    final total = entries.fold<int>(0, (s, e) => s + e.v);
    if (total == 0) return _sinDatos();
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        SizedBox(height: 200, child: Row(children: [
          Expanded(flex: 3, child: PieChart(PieChartData(sectionsSpace: 2, centerSpaceRadius: 30,
            sections: entries.map((e) => PieChartSectionData(value: e.v.toDouble(), color: e.c,
              title: '${(e.v / total * 100).toStringAsFixed(0)}%',
              titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white), radius: 60)).toList()))),
          if (!legendBelow) Expanded(flex: 2, child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start,
            children: entries.map((e) => Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: e.c, shape: BoxShape.circle)),
              const SizedBox(width: 6), Expanded(child: Text('${e.l} (${e.v})', style: const TextStyle(fontSize: 11, color: Colors.white70), overflow: TextOverflow.ellipsis)),
            ]))).toList())),
        ])),
        if (legendBelow) ...[const SizedBox(height: 12), Wrap(spacing: 12, runSpacing: 6, children: entries.map((e) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: e.c, shape: BoxShape.circle)),
          const SizedBox(width: 4), Text('${e.l} (${e.v})', style: const TextStyle(fontSize: 10, color: Colors.white70)),
        ])).toList())],
      ]));
  }

  Widget _buildPieTipo(DashboardStats s) {
    if (s.casosPorTipoRiesgo.isEmpty) return _sinDatos();
    final cols = [Colors.blue, Colors.orange, Colors.green, Colors.purple, Colors.pink, Colors.brown, Colors.teal, Colors.red, Colors.indigo, Colors.amber, Colors.cyan, Colors.deepOrange, Colors.lime];
    int i = 0;
    final entries = s.casosPorTipoRiesgo.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return _pie(entries.map((e) => _PE(e.key, e.value, cols[i++ % cols.length])).toList(), legendBelow: true);
  }

  Widget _buildPieNivel(DashboardStats s) {
    if (s.casosPorNivelPeligro.isEmpty) return _sinDatos();
    final cm = {'Bajo': Colors.green, 'Medio': Colors.orange, 'Alto': Colors.red};
    final entries = s.casosPorNivelPeligro.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return _pie(entries.map((e) => _PE(e.key, e.value, cm[e.key] ?? Colors.grey)).toList());
  }

  Widget _buildBarTendencia(DashboardStats s) {
    if (s.tendenciaMensual.isEmpty) return _sinDatos();
    final mx = s.tendenciaMensual.fold<int>(0, (m, e) => [m, e.creados, e.cerrados].reduce((a, b) => a > b ? a : b));
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        SizedBox(height: 200, child: BarChart(BarChartData(alignment: BarChartAlignment.spaceAround, maxY: (mx + 2).toDouble(),
          barTouchData: BarTouchData(touchTooltipData: BarTouchTooltipData(getTooltipItem: (g, gi, r, ri) {
            final m = s.tendenciaMensual[gi]; return BarTooltipItem(ri == 0 ? 'Creados: ${m.creados}' : 'Cerrados: ${m.cerrados}', const TextStyle(color: Colors.white, fontSize: 11));
          })),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) {
              final idx = v.toInt(); if (idx < 0 || idx >= s.tendenciaMensual.length) return const SizedBox();
              return Padding(padding: const EdgeInsets.only(top: 4), child: Text(s.tendenciaMensual[idx].etiqueta, style: const TextStyle(fontSize: 10, color: Colors.white60)));
            })),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, getTitlesWidget: (v, _) => Text('${v.toInt()}', style: const TextStyle(fontSize: 9, color: Colors.white38)))),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(show: true, getDrawingHorizontalLine: (_) => FlLine(color: Colors.white10, strokeWidth: 0.5), drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(s.tendenciaMensual.length, (i) { final m = s.tendenciaMensual[i];
            return BarChartGroupData(x: i, barRods: [
              BarChartRodData(toY: m.creados.toDouble(), color: Colors.blue, width: 10, borderRadius: BorderRadius.circular(3)),
              BarChartRodData(toY: m.cerrados.toDouble(), color: Colors.green, width: 10, borderRadius: BorderRadius.circular(3)),
            ]);
          }),
        ))),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [_dot(Colors.blue, 'Creados'), const SizedBox(width: 20), _dot(Colors.green, 'Cerrados')]),
      ]));
  }

  Widget _buildBarGrupos(DashboardStats s) {
    final gs = s.grupos.where((g) => g.totalCasos > 0).take(8).toList();
    if (gs.isEmpty) return _sinDatos();
    final mx = gs.fold<int>(0, (m, g) => g.totalCasos > m ? g.totalCasos : m);
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        SizedBox(height: (gs.length * 48.0).clamp(100, 400), child: BarChart(BarChartData(alignment: BarChartAlignment.spaceAround, maxY: (mx + 2).toDouble(),
          barTouchData: BarTouchData(touchTooltipData: BarTouchTooltipData(getTooltipItem: (g, gi, r, ri) {
            final gr = gs[gi]; return BarTooltipItem('${gr.nombre}\nAbier: ${gr.casosAbiertos} · Cerr: ${gr.casosCerrados}', const TextStyle(color: Colors.white, fontSize: 10));
          })),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, _) {
              final idx = v.toInt(); if (idx < 0 || idx >= gs.length) return const SizedBox();
              final n = gs[idx].nombre; return Padding(padding: const EdgeInsets.only(top: 4), child: Text(n.length > 10 ? '${n.substring(0, 10)}...' : n, style: const TextStyle(fontSize: 9, color: Colors.white60), textAlign: TextAlign.center));
            })),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24, getTitlesWidget: (v, _) => Text('${v.toInt()}', style: const TextStyle(fontSize: 9, color: Colors.white38)))),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(show: true, getDrawingHorizontalLine: (_) => FlLine(color: Colors.white10, strokeWidth: 0.5), drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(gs.length, (i) { final g = gs[i];
            return BarChartGroupData(x: i, barRods: [BarChartRodData(toY: g.totalCasos.toDouble(), width: 16, borderRadius: BorderRadius.circular(4), color: Colors.transparent,
              rodStackItems: [BarChartRodStackItem(0, g.casosAbiertos.toDouble(), Colors.orange), BarChartRodStackItem(g.casosAbiertos.toDouble(), g.totalCasos.toDouble(), Colors.green)])]);
          }),
        ))),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [_dot(Colors.orange, 'Abiertos'), const SizedBox(width: 20), _dot(Colors.green, 'Cerrados')]),
      ]));
  }

  Widget _buildTopInsp(DashboardStats s) => Container(
    decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
    child: Column(children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
        child: const Row(children: [
          Expanded(flex: 3, child: Text('Inspector', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70))),
          Expanded(flex: 2, child: Text('Grupo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70))),
          SizedBox(width: 50, child: Text('Casos', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70), textAlign: TextAlign.center)),
          SizedBox(width: 50, child: Text('Cerr.', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70), textAlign: TextAlign.center)),
        ])),
      ...s.topInspectores.asMap().entries.map((e) { final i = e.key; final insp = e.value;
        return Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), color: i.isEven ? Colors.white.withOpacity(0.03) : Colors.transparent,
          child: Row(children: [
            SizedBox(width: 20, child: Text('${i + 1}', style: TextStyle(fontSize: 11, color: i < 3 ? Colors.amber : Colors.white38))),
            Expanded(flex: 3, child: Text(insp.nombre, style: const TextStyle(fontSize: 12, color: Colors.white), overflow: TextOverflow.ellipsis)),
            Expanded(flex: 2, child: Text(insp.grupoNombre, style: const TextStyle(fontSize: 11, color: Colors.white54), overflow: TextOverflow.ellipsis)),
            SizedBox(width: 50, child: Text('${insp.casosCreados}', style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
            SizedBox(width: 50, child: Text('${insp.casosCerrados}', style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
          ]));
      }),
    ]));

  Widget _buildTablaGrupos(DashboardStats s) => Container(
    decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
    child: Column(children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
        child: const Row(children: [
          Expanded(flex: 3, child: Text('Grupo', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70))),
          SizedBox(width: 35, child: Text('Usu.', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70), textAlign: TextAlign.center)),
          SizedBox(width: 35, child: Text('Emp.', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70), textAlign: TextAlign.center)),
          SizedBox(width: 35, child: Text('Cen.', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70), textAlign: TextAlign.center)),
          SizedBox(width: 35, child: Text('Abier.', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70), textAlign: TextAlign.center)),
          SizedBox(width: 35, child: Text('Cerr.', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70), textAlign: TextAlign.center)),
        ])),
      ...s.grupos.asMap().entries.map((e) { final i = e.key; final g = e.value;
        return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), color: i.isEven ? Colors.white.withOpacity(0.03) : Colors.transparent,
          child: Row(children: [
            Expanded(flex: 3, child: Text(g.nombre, style: const TextStyle(fontSize: 11, color: Colors.white), overflow: TextOverflow.ellipsis)),
            SizedBox(width: 35, child: Text('${g.usuarios}', style: const TextStyle(fontSize: 11, color: Colors.blue), textAlign: TextAlign.center)),
            SizedBox(width: 35, child: Text('${g.empresas}', style: const TextStyle(fontSize: 11, color: Colors.teal), textAlign: TextAlign.center)),
            SizedBox(width: 35, child: Text('${g.centros}', style: const TextStyle(fontSize: 11, color: Colors.indigo), textAlign: TextAlign.center)),
            SizedBox(width: 35, child: Text('${g.casosAbiertos}', style: const TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
            SizedBox(width: 35, child: Text('${g.casosCerrados}', style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
          ]));
      }),
    ]));

  Widget _sec(String t) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)));
  Widget _dot(Color c, String l) => Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)), const SizedBox(width: 4), Text(l, style: const TextStyle(fontSize: 11, color: Colors.white60))]);
  Widget _sinDatos() => Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16)), child: const Center(child: Text('Sin datos', style: TextStyle(color: Colors.white38))));
}

class _PE { final String l; final int v; final Color c; const _PE(this.l, this.v, this.c); }