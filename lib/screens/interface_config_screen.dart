// lib/screens/interface_config_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../data/risk_data.dart';
import '../providers/interface_config_provider.dart';
import '../services/interface_config_service.dart';

class InterfaceConfigScreen extends StatefulWidget {
  const InterfaceConfigScreen({super.key});

  @override
  State<InterfaceConfigScreen> createState() => _InterfaceConfigScreenState();
}

class _InterfaceConfigScreenState extends State<InterfaceConfigScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Configuraciones disponibles
  bool _habilitarFotos = true;
  bool _habilitarFirmas = true;
  bool _mostrarNivelRiesgo = true;
  bool _isLoading = false;

  // Nuevas configuraciones de nivel de peligro
  bool _mostrarNivelPeligroEnDialog = false;
  bool _mostrarNivelPeligroEnDetalle = true;
  String _nivelPeligroDefault = 'Medio';

  // Configuración de subtipos de riesgo
  final Map<String, bool> _subtiposHabilitados = {};
  final Map<String, bool> _categoriasHabilitadas = {};
  bool _todosLosSubtipos = true;
  // Subtipos personalizados agregados por el admin (por categoria)
  Map<String, List<String>> _subtiposPersonalizados = {};

  // Categorías personalizadas del grupo (nuevas categorías completas)
  List<Map<String, dynamic>> _categoriasPersonalizadas = [];

  late String _groupId;
  late Map<String, dynamic> _groupData;
  late Map<String, dynamic> _currentConfig;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadArguments();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _loadArguments();
    }
  }

  void _loadArguments() {
    final route = ModalRoute.of(context);
    if (route == null) {
      _handleError('No se pudo acceder a la ruta');
      return;
    }

    final args = route.settings.arguments as Map?;
    if (args == null) {
      _handleError('No se recibieron argumentos');
      return;
    }

    try {
      _groupId = args['groupId'] as String;
      _groupData = args['groupData'] as Map<String, dynamic>;
      // No leer configInterfaz de los args — pueden estar desactualizados.
      // Cargar siempre desde Firestore para reflejar la config guardada.
      _loadConfigFromFirestore();
    } catch (e) {
      _handleError('Error al cargar los datos: $e');
    }
  }

  Future<void> _loadConfigFromFirestore() async {
    try {
      final doc = await _firestore.collection('grupos').doc(_groupId).get();
      if (!mounted) return;
      _currentConfig = (doc.data()?['configInterfaz'] as Map<String, dynamic>?) ?? {};

      // Cargar categorías personalizadas (campo separado de configInterfaz)
      final rawPersonalizadas =
          doc.data()?['categoriasPersonalizadas'] as List<dynamic>? ?? [];
      _categoriasPersonalizadas = rawPersonalizadas
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      _loadCurrentConfig();
      setState(() => _isInitialized = true);
    } catch (e) {
      _handleError('Error cargando configuración: $e');
    }
  }

  void _handleError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.pop(context);
    }
  }

  void _loadCurrentConfig() {
    // Cargar configuraciones existentes
    setState(() {
      _habilitarFotos = _currentConfig['habilitarFotos'] ?? true;
      _habilitarFirmas = _currentConfig['habilitarFirmas'] ?? true;
      _mostrarNivelRiesgo = _currentConfig['mostrarNivelRiesgo'] ?? true;

      // Nuevas configuraciones de nivel de peligro
      _mostrarNivelPeligroEnDialog = _currentConfig['mostrarNivelPeligroEnDialog'] ?? false;
      _mostrarNivelPeligroEnDetalle = _currentConfig['mostrarNivelPeligroEnDetalle'] ?? true;
      _nivelPeligroDefault = _currentConfig['nivelPeligroDefault'] ?? 'Medio';

      // Cargar configuración de subtipos
      _todosLosSubtipos = _currentConfig['todosLosSubtipos'] ?? true;
      
      // Inicializar mapas de subtipos y categorías
      _inicializarSubtipos();
    });
  }

  void _inicializarSubtipos() {
    // Inicializar todos los subtipos estándar como habilitados por defecto
    for (var categoria in matrizPeligros) {
      final categoriaNombre = categoria['categoria'] as String;
      _categoriasHabilitadas[categoriaNombre] = true;
      
      for (var subtipo in categoria['subgrupos'] as List<String>) {
        _subtiposHabilitados[subtipo] = true;
      }
    }

    // Inicializar subtipos de categorías personalizadas como habilitados por defecto
    for (var cat in _categoriasPersonalizadas) {
      final nombre = cat['categoria'] as String;
      _categoriasHabilitadas.putIfAbsent(nombre, () => true);
      final subs = cat['subgrupos'] as List<dynamic>? ?? [];
      for (var s in subs) {
        _subtiposHabilitados.putIfAbsent(s as String, () => true);
      }
    }

    // Cargar configuración guardada si existe
    // Los valores de Firestore llegan como dynamic, hay que castear explícitamente
    final subtiposConfig = _currentConfig['subtiposHabilitados'] as Map<String, dynamic>?;
    final categoriasConfig = _currentConfig['categoriasHabilitadas'] as Map<String, dynamic>?;
    
    if (subtiposConfig != null) {
      subtiposConfig.forEach((key, value) {
        _subtiposHabilitados[key] = value == true;
      });
    }
    if (categoriasConfig != null) {
      categoriasConfig.forEach((key, value) {
        _categoriasHabilitadas[key] = value == true;
      });
    }

    // Cargar subtipos personalizados (dentro de categorías estándar)
    final personalizadosConfig = _currentConfig['subtiposPersonalizados'] as Map<String, dynamic>?;
    if (personalizadosConfig != null) {
      personalizadosConfig.forEach((categoria, lista) {
        if (lista is List) {
          _subtiposPersonalizados[categoria] = List<String>.from(lista);
          // Asegurarse de que cada subtipo personalizado tenga un valor en el mapa
          for (var subtipo in _subtiposPersonalizados[categoria]!) {
            _subtiposHabilitados.putIfAbsent(subtipo, () => true);
          }
        }
      });
    }
  }

  /// Verifica si hay al menos un subtipo habilitado en toda la configuración.
  bool _hayAlMenosUnSubtipoHabilitado() {
    return _subtiposHabilitados.values.any((v) => v == true);
  }

  Future<void> _guardarConfiguracion() async {
    // Validar que haya al menos un tipo de peligro seleccionado
    if (!_todosLosSubtipos && !_hayAlMenosUnSubtipoHabilitado()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe haber al menos un tipo de peligro habilitado'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final configData = {
        'habilitarFotos': _habilitarFotos,
        'habilitarFirmas': _habilitarFirmas,
        'mostrarNivelRiesgo': _mostrarNivelRiesgo,

        // Nuevas configuraciones de nivel de peligro
        'mostrarNivelPeligroEnDialog': _mostrarNivelPeligroEnDialog,
        'mostrarNivelPeligroEnDetalle': _mostrarNivelPeligroEnDetalle,
        'nivelPeligroDefault': _nivelPeligroDefault,

        'todosLosSubtipos': _todosLosSubtipos,
        'subtiposHabilitados': _subtiposHabilitados,
        'categoriasHabilitadas': _categoriasHabilitadas,
        'subtiposPersonalizados': _subtiposPersonalizados,
        'ultimaActualizacion': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('grupos').doc(_groupId).update({
        'configInterfaz': configData,
      });

      if (mounted) {
        // Refrescar el provider para que los cambios se reflejen inmediatamente
        final configProvider = Provider.of<InterfaceConfigProvider>(context, listen: false);
        await configProvider.reloadConfig(_groupId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuración guardada exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _restablecerConfiguracion() {
    setState(() {
      _habilitarFotos = true;
      _habilitarFirmas = true;
      _mostrarNivelRiesgo = true;

      // Nuevas configuraciones - valores por defecto
      _mostrarNivelPeligroEnDialog = false;
      _mostrarNivelPeligroEnDetalle = true;
      _nivelPeligroDefault = 'Medio';

      _todosLosSubtipos = true;
      _subtiposPersonalizados = {};
      _inicializarSubtipos();
      // Nota: _categoriasPersonalizadas NO se restaura — son datos de Firestore
    });
  }

  // Métodos para manejar selección de subtipos
  void _seleccionarTodosSubtipos(bool seleccionar) {
    setState(() {
      _todosLosSubtipos = seleccionar;
      if (seleccionar) {
        // Habilitar todos los subtipos
        for (var key in _subtiposHabilitados.keys) {
          _subtiposHabilitados[key] = true;
        }
        for (var key in _categoriasHabilitadas.keys) {
          _categoriasHabilitadas[key] = true;
        }
      }
    });
  }

  void _seleccionarCategoria(String categoria, bool seleccionar) {
    setState(() {
      _categoriasHabilitadas[categoria] = seleccionar;
      _todosLosSubtipos = false;

      // Habilitar/deshabilitar subtipos base de categorías estándar
      final categoriaData = RiskData.getCategoriaPorNombre(categoria);
      if (categoriaData != null) {
        for (var subtipo in categoriaData['subgrupos'] as List<String>) {
          _subtiposHabilitados[subtipo] = seleccionar;
        }
      }

      // Habilitar/deshabilitar subtipos de categoría personalizada
      final catPersonalizada = _categoriasPersonalizadas
          .where((c) => c['categoria'] == categoria)
          .firstOrNull;
      if (catPersonalizada != null) {
        final subs = catPersonalizada['subgrupos'] as List<dynamic>? ?? [];
        for (var s in subs) {
          _subtiposHabilitados[s as String] = seleccionar;
        }
      }

      // Habilitar/deshabilitar subtipos personalizados de esta categoria (estándar)
      for (var subtipo in (_subtiposPersonalizados[categoria] ?? [])) {
        _subtiposHabilitados[subtipo] = seleccionar;
      }
    });
  }

  void _agregarSubtipoPersonalizado(String categoria) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.add_circle_outline, color: Colors.blue),
            SizedBox(width: 8),
            Text('Agregar subtipo'),
          ],
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nombre del subtipo',
            border: OutlineInputBorder(),
            hintText: 'Ej: Ruido de impacto',
          ),
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (_) => Navigator.pop(context, true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Agregar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ).then((confirmar) {
      if (confirmar == true) {
        final nombre = ctrl.text.trim();
        if (nombre.isEmpty) return;
        // Evitar duplicados
        final yaExiste = (_subtiposPersonalizados[categoria] ?? []).contains(nombre) ||
            (RiskData.getCategoriaPorNombre(categoria)?['subgrupos'] as List<String>?)
                ?.contains(nombre) == true;
        if (yaExiste) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ese subtipo ya existe')),
          );
          return;
        }
        setState(() {
          _subtiposPersonalizados.putIfAbsent(categoria, () => []).add(nombre);
          _subtiposHabilitados[nombre] = true;
        });
      }
    });
  }

  void _seleccionarSubtipo(String subtipo, bool seleccionar) {
    setState(() {
      _subtiposHabilitados[subtipo] = seleccionar;
      _todosLosSubtipos = false;
      
      // Verificar si toda la categoría está seleccionada
      _actualizarEstadoCategorias();
    });
  }

  void _actualizarEstadoCategorias() {
    // Categorías estándar
    for (var categoria in matrizPeligros) {
      final categoriaNombre = categoria['categoria'] as String;
      final subgruposBase = categoria['subgrupos'] as List<String>;
      final subgruposPersonalizados = _subtiposPersonalizados[categoriaNombre] ?? [];
      final todosSubgrupos = [...subgruposBase, ...subgruposPersonalizados];

      // La categoria permanece habilitada (expandida) si al menos UN subtipo esta activo.
      final algunoHabilitado = todosSubgrupos.any((s) => _subtiposHabilitados[s] == true);
      if (algunoHabilitado) {
        _categoriasHabilitadas[categoriaNombre] = true;
      }
      // Si ninguno esta habilitado la dejamos en false (desactivada por el usuario).
    }

    // Categorías personalizadas
    for (var cat in _categoriasPersonalizadas) {
      final nombre = cat['categoria'] as String;
      final subs = (cat['subgrupos'] as List<dynamic>? ?? []).cast<String>();
      final algunoHabilitado = subs.any((s) => _subtiposHabilitados[s] == true);
      if (algunoHabilitado) {
        _categoriasHabilitadas[nombre] = true;
      }
    }

    // FIX: Verificar que TODOS estén seleccionados Y que haya al menos uno.
    // Sin la segunda condición, .every() devuelve true sobre una lista vacía
    // y reactiva el switch "Usar todos" cuando se desactiva el último subtipo.
    final valores = _subtiposHabilitados.values;
    _todosLosSubtipos = valores.isNotEmpty && valores.every((value) => value == true);
  }

  // ═══════════════════════════════════════════════════════════════════
  //  CATEGORÍAS PERSONALIZADAS — CRUD
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _showAddEditCategoriaDialog({Map<String, dynamic>? existing}) async {
    await showDialog(
      context: context,
      builder: (_) => _CategoriaDialog(
        grupoId: _groupId,
        existing: existing,
        nextNumero: RiskData.getNextNumeroCategoria(_categoriasPersonalizadas),
        onSaved: (cat) async {
          try {
            if (existing == null) {
              await InterfaceConfigService.addCategoriaPersonalizada(_groupId, cat);
              setState(() {
                _categoriasPersonalizadas.add(cat);
                // Inicializar sus subtipos en los mapas
                _categoriasHabilitadas[cat['categoria'] as String] = true;
                for (var s in (cat['subgrupos'] as List<dynamic>? ?? [])) {
                  _subtiposHabilitados[s as String] = true;
                }
              });
            } else {
              await InterfaceConfigService.updateCategoriaPersonalizada(_groupId, cat);
              setState(() {
                final idx = _categoriasPersonalizadas
                    .indexWhere((c) => c['id'] == cat['id']);
                if (idx != -1) _categoriasPersonalizadas[idx] = cat;
                // Actualizar subtipos en los mapas
                for (var s in (cat['subgrupos'] as List<dynamic>? ?? [])) {
                  _subtiposHabilitados.putIfAbsent(s as String, () => true);
                }
              });
            }
            // Refrescar el provider
            if (mounted) {
              Provider.of<InterfaceConfigProvider>(context, listen: false)
                  .reloadConfig(_groupId);
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _confirmarEliminarCategoria(Map<String, dynamic> cat) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Eliminar categoría'),
          ],
        ),
        content: Text(
          '¿Eliminar la categoría "${cat['categoria']}"?\n\n'
          'Los casos existentes que usen esta categoría no se verán afectados, '
          'pero no podrán crear nuevos casos con ella.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await InterfaceConfigService.deleteCategoriaPersonalizada(
            _groupId, cat['id'] as String);
        setState(() {
          _categoriasPersonalizadas.removeWhere((c) => c['id'] == cat['id']);
          // Limpiar sus subtipos de los mapas
          final nombre = cat['categoria'] as String;
          _categoriasHabilitadas.remove(nombre);
          for (var s in (cat['subgrupos'] as List<dynamic>? ?? [])) {
            _subtiposHabilitados.remove(s as String);
          }
        });
        if (mounted) {
          Provider.of<InterfaceConfigProvider>(context, listen: false)
              .reloadConfig(_groupId);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Categoría eliminada'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Configurar Interfaz'),
          backgroundColor: Colors.blue,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurar Interfaz'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _guardarConfiguracion,
            tooltip: 'Guardar Configuración',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Información del grupo
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _groupData['nombre'] ?? 'Sin nombre',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _groupData['descripcion'] ?? 'Sin descripción',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'ID: $_groupId',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Sección: Tipos de Peligro (estándar + habilitar/deshabilitar)
                  _buildSectionTitle('Configuración de Tipos de Peligro'),
                  _buildSubtiposConfiguracion(),
                  const SizedBox(height: 24),

                  // Sección: Categorías Personalizadas (CRUD)
                  _buildSectionTitle('Categorías Personalizadas'),
                  _buildCategoriasPersonalizadas(),
                  const SizedBox(height: 24),

                  // Sección: Configuración de Nivel de Peligro
                  _buildSectionTitle('Configuración de Nivel de Peligro'),
                  _buildSwitchOption(
                    'Mostrar en Pantalla de Detalles',
                    _mostrarNivelPeligroEnDetalle,
                    (value) => setState(() => _mostrarNivelPeligroEnDetalle = value),
                    icon: Icons.visibility,
                    subtitle: 'Mostrar el campo de nivel de peligro en la pantalla de detalles del caso',
                  ),
                  _buildSwitchOption(
                    'Mostrar en Dialog de Creación',
                    _mostrarNivelPeligroEnDialog,
                    (value) => setState(() => _mostrarNivelPeligroEnDialog = value),
                    icon: Icons.add_box,
                    subtitle: 'Mostrar el campo de nivel de peligro al crear un nuevo caso',
                  ),
                  const SizedBox(height: 16),

                  // Selector de nivel de peligro por defecto
                  _buildSubtitle('Nivel de Peligro por Defecto'),
                  DropdownButtonFormField<String>(
                    initialValue: _nivelPeligroDefault,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Selecciona nivel por defecto',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Bajo', child: Text('Bajo')),
                      DropdownMenuItem(value: 'Medio', child: Text('Medio')),
                      DropdownMenuItem(value: 'Alto', child: Text('Alto')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _nivelPeligroDefault = value);
                      }
                    },
                  ),
                  const SizedBox(height: 24),

                  // Sección: Funcionalidades
                  _buildSectionTitle('Funcionalidades'),
                  _buildSwitchOption(
                    'Habilitar Fotos',
                    _habilitarFotos,
                    (value) => setState(() => _habilitarFotos = value),
                    icon: Icons.photo_camera,
                  ),
                  _buildSwitchOption(
                    'Habilitar Firmas',
                    _habilitarFirmas,
                    (value) => setState(() => _habilitarFirmas = value),
                    icon: Icons.draw,
                  ),
                  _buildSwitchOption(
                    'Mostrar Nivel de Riesgo',
                    _mostrarNivelRiesgo,
                    (value) => setState(() => _mostrarNivelRiesgo = value),
                    icon: Icons.warning,
                  ),
                  const SizedBox(height: 32),

                  // Botones de acción
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _restablecerConfiguracion,
                          icon: const Icon(Icons.restore),
                          label: const Text('Restablecer'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _guardarConfiguracion,
                          icon: const Icon(Icons.save),
                          label: const Text('Guardar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  WIDGETS
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildSubtiposConfiguracion() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Opción para seleccionar todos
            _buildSwitchOption(
              'Usar todos los tipos de peligro',
              _todosLosSubtipos,
              _seleccionarTodosSubtipos,
              icon: Icons.select_all,
            ),
            const SizedBox(height: 16),
            
            // Lista de categorías y subtipos (solo si no están todos seleccionados)
            if (!_todosLosSubtipos) ...[
              const Text(
                'Seleccione los tipos de peligro disponibles:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              
              // Lista de categorías estándar
              ...matrizPeligros.map((categoria) {
                final categoriaNombre = categoria['categoria'] as String;
                final subgrupos = categoria['subgrupos'] as List<String>;
                final icon = categoria['icon'] as IconData;
                final color = categoria['color'] as Color;
                
                return _buildCategoriaItem(
                  categoriaNombre,
                  icon,
                  color,
                  subgrupos,
                );
              }),

              // Lista de categorías personalizadas
              ..._categoriasPersonalizadas.map((cat) {
                final nombre = cat['categoria'] as String;
                final icon = RiskData.getIconDataFromName(
                    cat['iconName'] as String? ?? 'warning');
                final color = RiskData.getColorFromHex(
                    cat['colorHex'] as String? ?? '#2196F3');
                final subs = (cat['subgrupos'] as List<dynamic>? ?? [])
                    .cast<String>();
                return _buildCategoriaItem(nombre, icon, color, subs);
              }),
            ] else ...[
              const Text(
                'Todos los tipos de peligro estarán disponibles para selección.',
                style: TextStyle(
                  color: Colors.green,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriasPersonalizadas() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_categoriasPersonalizadas.isEmpty)
              const Text(
                'Aún no hay categorías personalizadas.\n'
                'Puedes crear categorías específicas para tu sector o actividad.',
                style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
              )
            else
              ..._categoriasPersonalizadas.map((cat) {
                final icon = RiskData.getIconDataFromName(
                    cat['iconName'] as String? ?? 'warning');
                final color = RiskData.getColorFromHex(
                    cat['colorHex'] as String? ?? '#2196F3');
                final subs = (cat['subgrupos'] as List<dynamic>? ?? []).cast<String>();

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: color.withOpacity(0.4)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: color.withOpacity(0.15),
                      child: Icon(icon, color: color, size: 22),
                    ),
                    title: Text(
                      cat['categoria'] as String,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    subtitle: Text(
                      '${subs.length} subgrupo${subs.length != 1 ? 's' : ''}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          onPressed: () =>
                              _showAddEditCategoriaDialog(existing: cat),
                          tooltip: 'Editar',
                          color: Colors.blue,
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () => _confirmarEliminarCategoria(cat),
                          tooltip: 'Eliminar',
                          color: Colors.red,
                        ),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showAddEditCategoriaDialog(),
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Agregar categoría personalizada'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriaItem(String categoriaNombre, IconData icon, Color color, List<String> subgrupos) {
    final categoriaHabilitada = _categoriasHabilitadas[categoriaNombre] ?? false;
    final personalizados = _subtiposPersonalizados[categoriaNombre] ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Header de la categoria
          ListTile(
            leading: Icon(icon, color: color),
            title: Text(
              categoriaNombre,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            trailing: Switch(
              value: categoriaHabilitada,
              onChanged: (value) => _seleccionarCategoria(categoriaNombre, value),
              activeThumbColor: color,
            ),
            onTap: () => _seleccionarCategoria(categoriaNombre, !categoriaHabilitada),
          ),

          // Subtipos (solo visibles si la categoria esta habilitada)
          if (categoriaHabilitada) ...[
            const Divider(height: 1),
            // Subtipos base
            ...subgrupos.map((subtipo) {
              final subtipoHabilitado = _subtiposHabilitados[subtipo] ?? false;
              return CheckboxListTile(
                title: Text(
                  subtipo,
                  style: TextStyle(
                    fontSize: 14,
                    color: subtipoHabilitado ? Colors.black87 : Colors.grey,
                  ),
                ),
                value: subtipoHabilitado,
                onChanged: (value) => _seleccionarSubtipo(subtipo, value ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                contentPadding: const EdgeInsets.only(left: 56, right: 16),
              );
            }),
            // Subtipos personalizados (dentro de categorías estándar)
            ...personalizados.map((subtipo) {
              final subtipoHabilitado = _subtiposHabilitados[subtipo] ?? true;
              return CheckboxListTile(
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        subtipo,
                        style: TextStyle(
                          fontSize: 14,
                          color: subtipoHabilitado ? Colors.black87 : Colors.grey,
                        ),
                      ),
                    ),
                    // Icono que indica que es personalizado
                    const Icon(Icons.edit_note, size: 14, color: Colors.blue),
                  ],
                ),
                value: subtipoHabilitado,
                onChanged: (value) => _seleccionarSubtipo(subtipo, value ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                contentPadding: const EdgeInsets.only(left: 56, right: 8),
              );
            }),
            // Boton agregar subtipo (solo en categorías estándar)
            if (RiskData.getCategoriaPorNombre(categoriaNombre) != null)
              InkWell(
                onTap: () => _agregarSubtipoPersonalizado(categoriaNombre),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_circle_outline, size: 16, color: color),
                      const SizedBox(width: 6),
                      Text(
                        'Agregar subtipo',
                        style: TextStyle(
                          fontSize: 13,
                          color: color,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    );
  }

  Widget _buildSubtitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildSwitchOption(String title, bool value, Function(bool) onChanged, {IconData? icon, String? subtitle}) {
    return Card(
      child: ListTile(
        leading: icon != null ? Icon(icon) : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ],
        ),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: Colors.blue,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  DIÁLOGO PARA CREAR / EDITAR CATEGORÍA PERSONALIZADA
// ═══════════════════════════════════════════════════════════════════════

class _CategoriaDialog extends StatefulWidget {
  final String grupoId;
  final Map<String, dynamic>? existing;
  final int nextNumero;
  final Future<void> Function(Map<String, dynamic>) onSaved;

  const _CategoriaDialog({
    required this.grupoId,
    required this.nextNumero,
    required this.onSaved,
    this.existing,
  });

  @override
  State<_CategoriaDialog> createState() => _CategoriaDialogState();
}

class _CategoriaDialogState extends State<_CategoriaDialog> {
  final _nameCtrl = TextEditingController();
  String _selectedIconName = 'warning';
  String _selectedColorHex = '#2196F3';
  List<String> _subgrupos = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _nameCtrl.text = widget.existing!['categoria'] as String? ?? '';
      _selectedIconName = widget.existing!['iconName'] as String? ?? 'warning';
      _selectedColorHex = widget.existing!['colorHex'] as String? ?? '#2196F3';
      final subs = widget.existing!['subgrupos'] as List<dynamic>? ?? [];
      _subgrupos = subs.cast<String>().toList();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nombre = _nameCtrl.text.trim();
    if (nombre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre es requerido')),
      );
      return;
    }
    if (_subgrupos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos un subgrupo')),
      );
      return;
    }

    setState(() => _saving = true);

    final cat = {
      'id': widget.existing?['id'] ??
          'cat_${DateTime.now().millisecondsSinceEpoch}',
      'categoria': nombre,
      'numeroCategoria': widget.existing?['numeroCategoria'] ?? widget.nextNumero,
      'subgrupos': _subgrupos,
      'iconName': _selectedIconName,
      'colorHex': _selectedColorHex,
      'esPersonalizada': true,
    };

    try {
      await widget.onSaved(cat);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addSubgrupo() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nuevo subgrupo'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Ej: Rayos X',
          ),
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (_) => Navigator.pop(context, true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Agregar'),
          ),
        ],
      ),
    ).then((ok) {
      if (ok == true) {
        final s = ctrl.text.trim();
        if (s.isNotEmpty && !_subgrupos.contains(s)) {
          setState(() => _subgrupos.add(s));
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    final selectedColor = RiskData.getColorFromHex(_selectedColorHex);

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.9,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Título
              Row(
                children: [
                  Icon(
                    isEditing ? Icons.edit_outlined : Icons.add_circle_outline,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isEditing ? 'Editar categoría' : 'Nueva categoría',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nombre
                      const Text('Nombre de la categoría',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nameCtrl,
                        autofocus: !isEditing,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Ej: Radiológico',
                        ),
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 20),

                      // Ícono
                      const Text('Ícono',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 8),
                      _buildIconPicker(),
                      const SizedBox(height: 20),

                      // Color
                      const Text('Color',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 8),
                      _buildColorPicker(),
                      const SizedBox(height: 20),

                      // Subgrupos
                      Row(
                        children: [
                          const Text('Subgrupos',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13)),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _addSubgrupo,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Agregar'),
                            style: TextButton.styleFrom(
                                foregroundColor: Colors.blue,
                                padding: EdgeInsets.zero),
                          ),
                        ],
                      ),
                      if (_subgrupos.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Sin subgrupos. Agrega al menos uno.',
                            style: TextStyle(
                                color: Colors.grey, fontStyle: FontStyle.italic),
                          ),
                        )
                      else
                        ..._subgrupos.asMap().entries.map((entry) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: selectedColor.withOpacity(0.05),
                              border: Border.all(
                                  color: selectedColor.withOpacity(0.3)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListTile(
                              dense: true,
                              leading: Icon(Icons.drag_indicator,
                                  color: Colors.grey[400], size: 18),
                              title: Text(entry.value,
                                  style: const TextStyle(fontSize: 14)),
                              trailing: IconButton(
                                icon: const Icon(Icons.close,
                                    size: 16, color: Colors.red),
                                onPressed: () => setState(
                                    () => _subgrupos.removeAt(entry.key)),
                                tooltip: 'Eliminar',
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Botones
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style:
                          ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                      child: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              isEditing ? 'Guardar' : 'Crear',
                              style: const TextStyle(color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconPicker() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: riskIconMap.entries.map((entry) {
        final isSelected = _selectedIconName == entry.key;
        final color = RiskData.getColorFromHex(_selectedColorHex);
        return GestureDetector(
          onTap: () => setState(() => _selectedIconName = entry.key),
          child: Tooltip(
            message: riskIconLabels[entry.key] ?? entry.key,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected ? color.withOpacity(0.15) : Colors.grey[100],
                border: Border.all(
                  color: isSelected ? color : Colors.grey[300]!,
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                entry.value,
                color: isSelected ? color : Colors.grey[600],
                size: 22,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildColorPicker() {
    final colors = InterfaceConfigService.getAvailableColors();
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: colors.map((c) {
        final col = c['color'] as Color;
        final hex = RiskData.getHexFromColor(col);
        final isSelected = _selectedColorHex == hex;
        return GestureDetector(
          onTap: () => setState(() => _selectedColorHex = hex),
          child: Tooltip(
            message: c['label'] as String,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: col,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.black87 : Colors.transparent,
                  width: 3,
                ),
                boxShadow: isSelected
                    ? [BoxShadow(color: col.withOpacity(0.5), blurRadius: 6)]
                    : null,
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : null,
            ),
          ),
        );
      }).toList(),
    );
  }
}