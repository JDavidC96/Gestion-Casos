// lib/screens/interface_config_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../data/risk_data.dart';
import '../providers/interface_config_provider.dart';

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
  Map<String, bool> _subtiposHabilitados = {};
  Map<String, bool> _categoriasHabilitadas = {};
  bool _todosLosSubtipos = true;
  // Subtipos personalizados agregados por el admin (por categoria)
  Map<String, List<String>> _subtiposPersonalizados = {};

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
    // Inicializar todos los subtipos como habilitados por defecto
    for (var categoria in matrizPeligros) {
      final categoriaNombre = categoria['categoria'] as String;
      _categoriasHabilitadas[categoriaNombre] = true;
      
      for (var subtipo in categoria['subgrupos'] as List<String>) {
        _subtiposHabilitados[subtipo] = true;
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

    // Cargar subtipos personalizados
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

  Future<void> _guardarConfiguracion() async {
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

      // Habilitar/deshabilitar subtipos base
      final categoriaData = RiskData.getCategoriaPorNombre(categoria);
      if (categoriaData != null) {
        for (var subtipo in categoriaData['subgrupos'] as List<String>) {
          _subtiposHabilitados[subtipo] = seleccionar;
        }
      }
      // Habilitar/deshabilitar subtipos personalizados de esta categoria
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

    // Verificar si todos los subtipos estan seleccionados
    _todosLosSubtipos = _subtiposHabilitados.values.every((value) => value == true);
  }

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

                  // Sección: Tipos de Peligro
                  _buildSectionTitle('Configuración de Tipos de Peligro'),
                  _buildSubtiposConfiguracion(),
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
                    value: _nivelPeligroDefault,
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
              
              // Lista de categorías
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
              }).toList(),
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
              activeColor: color,
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
            }).toList(),
            // Subtipos personalizados
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
            }).toList(),
            // Boton agregar subtipo
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
          activeColor: Colors.blue,
        ),
      ),
    );
  }
}