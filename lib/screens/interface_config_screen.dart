// lib/screens/interface_config_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/risk_data.dart';

class InterfaceConfigScreen extends StatefulWidget {
  const InterfaceConfigScreen({super.key});

  @override
  State<InterfaceConfigScreen> createState() => _InterfaceConfigScreenState();
}

class _InterfaceConfigScreenState extends State<InterfaceConfigScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Configuraciones disponibles
  bool _mostrarCasosCerrados = true;
  bool _mostrarEstadisticas = true;
  bool _habilitarFotos = true;
  bool _habilitarFirmas = true;
  bool _mostrarNivelRiesgo = true;
  bool _mostrarUbicacion = true;
  String _temaSeleccionado = 'default';
  String _colorPrimario = 'blue';
  bool _isLoading = false;

  // Nuevas configuraciones de nivel de peligro
  bool _mostrarNivelPeligroEnDialog = false;
  bool _mostrarNivelPeligroEnDetalle = true;
  String _nivelPeligroDefault = 'Medio';

  // Configuración de subtipos de riesgo
  Map<String, bool> _subtiposHabilitados = {};
  Map<String, bool> _categoriasHabilitadas = {};
  bool _todosLosSubtipos = true;

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
      _currentConfig = _groupData['configInterfaz'] ?? {};
      _loadCurrentConfig();
      _isInitialized = true;
    } catch (e) {
      _handleError('Error al cargar los datos: $e');
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
      _mostrarCasosCerrados = _currentConfig['mostrarCasosCerrados'] ?? true;
      _mostrarEstadisticas = _currentConfig['mostrarEstadisticas'] ?? true;
      _habilitarFotos = _currentConfig['habilitarFotos'] ?? true;
      _habilitarFirmas = _currentConfig['habilitarFirmas'] ?? true;
      _mostrarNivelRiesgo = _currentConfig['mostrarNivelRiesgo'] ?? true;
      _mostrarUbicacion = _currentConfig['mostrarUbicacion'] ?? true;
      _temaSeleccionado = _currentConfig['tema'] ?? 'default';
      _colorPrimario = _currentConfig['colorPrimario'] ?? 'blue';

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
    final subtiposConfig = _currentConfig['subtiposHabilitados'] as Map<String, dynamic>?;
    final categoriasConfig = _currentConfig['categoriasHabilitadas'] as Map<String, dynamic>?;
    
    if (subtiposConfig != null) {
      _subtiposHabilitados = Map<String, bool>.from(subtiposConfig);
    }
    if (categoriasConfig != null) {
      _categoriasHabilitadas = Map<String, bool>.from(categoriasConfig);
    }
  }

  Future<void> _guardarConfiguracion() async {
    setState(() => _isLoading = true);

    try {
      final configData = {
        'mostrarCasosCerrados': _mostrarCasosCerrados,
        'mostrarEstadisticas': _mostrarEstadisticas,
        'habilitarFotos': _habilitarFotos,
        'habilitarFirmas': _habilitarFirmas,
        'mostrarNivelRiesgo': _mostrarNivelRiesgo,
        'mostrarUbicacion': _mostrarUbicacion,
        'tema': _temaSeleccionado,
        'colorPrimario': _colorPrimario,

        // Nuevas configuraciones de nivel de peligro
        'mostrarNivelPeligroEnDialog': _mostrarNivelPeligroEnDialog,
        'mostrarNivelPeligroEnDetalle': _mostrarNivelPeligroEnDetalle,
        'nivelPeligroDefault': _nivelPeligroDefault,

        'todosLosSubtipos': _todosLosSubtipos,
        'subtiposHabilitados': _subtiposHabilitados,
        'categoriasHabilitadas': _categoriasHabilitadas,
        'ultimaActualizacion': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('grupos').doc(_groupId).update({
        'configInterfaz': configData,
      });

      if (mounted) {
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
      _mostrarCasosCerrados = true;
      _mostrarEstadisticas = true;
      _habilitarFotos = true;
      _habilitarFirmas = true;
      _mostrarNivelRiesgo = true;
      _mostrarUbicacion = true;
      _temaSeleccionado = 'default';
      _colorPrimario = 'blue';

      // Nuevas configuraciones - valores por defecto
      _mostrarNivelPeligroEnDialog = false;
      _mostrarNivelPeligroEnDetalle = true;
      _nivelPeligroDefault = 'Medio';

      _todosLosSubtipos = true;
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
      
      // Habilitar/deshabilitar todos los subtipos de la categoría
      final categoriaData = RiskData.getCategoriaPorNombre(categoria);
      if (categoriaData != null) {
        final subgrupos = categoriaData['subgrupos'] as List<String>;
        for (var subtipo in subgrupos) {
          _subtiposHabilitados[subtipo] = seleccionar;
        }
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
      final subgrupos = categoria['subgrupos'] as List<String>;
      
      bool todosHabilitados = true;
      for (var subtipo in subgrupos) {
        if (_subtiposHabilitados[subtipo] != true) {
          todosHabilitados = false;
          break;
        }
      }
      _categoriasHabilitadas[categoriaNombre] = todosHabilitados;
    }
    
    // Verificar si todos los subtipos están seleccionados
    _todosLosSubtipos = _subtiposHabilitados.values.every((value) => value == true);
  }

  Color _getColorFromString(String colorName) {
    switch (colorName) {
      case 'blue': return Colors.blue;
      case 'green': return Colors.green;
      case 'orange': return Colors.orange;
      case 'purple': return Colors.purple;
      case 'red': return Colors.red;
      case 'teal': return Colors.teal;
      default: return Colors.blue;
    }
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
        backgroundColor: _getColorFromString(_colorPrimario),
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

                  // Sección: Apariencia
                  _buildSectionTitle('Apariencia General'),
                  _buildSwitchOption(
                    'Tema Oscuro',
                    _temaSeleccionado == 'dark',
                    (value) {
                      setState(() {
                        _temaSeleccionado = value ? 'dark' : 'default';
                      });
                    },
                    icon: Icons.dark_mode,
                  ),
                  const SizedBox(height: 16),
                  
                  _buildSubtitle('Color Principal'),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildColorOption('Azul', 'blue', Colors.blue),
                      _buildColorOption('Verde', 'green', Colors.green),
                      _buildColorOption('Naranja', 'orange', Colors.orange),
                      _buildColorOption('Morado', 'purple', Colors.purple),
                      _buildColorOption('Rojo', 'red', Colors.red),
                      _buildColorOption('Verde Azulado', 'teal', Colors.teal),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Sección: Funcionalidades
                  _buildSectionTitle('Funcionalidades'),
                  _buildSwitchOption(
                    'Mostrar Casos Cerrados',
                    _mostrarCasosCerrados,
                    (value) => setState(() => _mostrarCasosCerrados = value),
                    icon: Icons.archive,
                  ),
                  _buildSwitchOption(
                    'Mostrar Estadísticas',
                    _mostrarEstadisticas,
                    (value) => setState(() => _mostrarEstadisticas = value),
                    icon: Icons.analytics,
                  ),
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
                  _buildSwitchOption(
                    'Mostrar Ubicación',
                    _mostrarUbicacion,
                    (value) => setState(() => _mostrarUbicacion = value),
                    icon: Icons.location_on,
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
                            backgroundColor: _getColorFromString(_colorPrimario),
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
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Header de la categoría
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
          
          // Subtipos de la categoría
          if (categoriaHabilitada) ...[
            const Divider(height: 1),
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
          activeColor: _getColorFromString(_colorPrimario),
        ),
      ),
    );
  }

  Widget _buildColorOption(String label, String colorValue, Color color) {
    final isSelected = _colorPrimario == colorValue;
    
    return GestureDetector(
      onTap: () => setState(() => _colorPrimario = colorValue),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}