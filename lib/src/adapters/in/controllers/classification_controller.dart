import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../application/ports/input/classify_image_port.dart';
import '../../../application/usecases/save_inspection_usecase.dart';
import '../../../application/ports/output/location_port.dart';
import '../../../domain/entities/road_incidence.dart';
import '../../../domain/exceptions/ai_classification_exception.dart';
import '../../../domain/constants/geo_thresholds.dart';
import '../../../domain/valueobjects/damage_level.dart';
import '../../../application/ports/output/local_storage_port.dart';
import 'dart:math' show cos, sqrt, asin;

import '../../../domain/services/road_safety_service.dart'; // Import RoadSafetyService
//DEFINICION DE ENUMS PARA LOS ESTADOS DE CLASIFICACIÓN Y GUARDADO,
//PERMITE A LA UI SABER CUANDO MOSTRAR CARGANDO, RESULTADOS, O MENSAJES DE ERROR.
enum ClassificationState { idle, loading, success, error }
enum SaveState { idle, saving, saved, error }
enum SyncStatus { idle, syncing, completed, error }

//HABLA CON EL DOMINIO PARA CLASIFICAR LA IMAGEN Y GUARDAR LA INSPECCIÓN, 
//MANEJA LOS ESTADOS DE CARGA Y ERROR, Y NOTIFICA A LA UI CUANDO HAY CAMBIOS
class ClassificationController extends ChangeNotifier {
  final ClassifyImagePort _classifyImagePort;
  final SaveInspectionUsecase _saveInspectionUsecase;
  final LocationPort _locationPort;
  final LocalStoragePort _localStoragePort;

  ClassificationController(
    this._classifyImagePort,
    this._saveInspectionUsecase,
    this._locationPort,
    this._localStoragePort,
  ) {
    updatePendingCount();
    _startLocationMonitoring(); // Initialize continuous location monitoring for alerts
  }

  ClassificationState _state = ClassificationState.idle;
  SaveState _saveState = SaveState.idle;
  SyncStatus _syncStatus = SyncStatus.idle;
  RoadIncidence? _result;
  String? _errorMessage;
  String? _warningMessage; // HU-06/07: Para avisos no bloqueantes como el GPS
  int? _georefLatencyMs; // PoC UC-IA-12: Para evidenciar el KPI de < 3s
  String? _selectedImagePath;
  String? _savedDocumentId;
  String _observations = ''; // HU-07
  String? _userAddress; // [HU-20/21/22]: User's current address for map and alerts
  ({double latitude, double longitude, String? address})? _userLocation; // Cache de ubicación del usuario
  int _pendingCount = 0;
  List<Map<String, dynamic>> _pendingReportsList = []; // [NUEVO]: Lista para gestión
  final Set<String> _selectedIds = {}; // [NUEVO]: IDs seleccionados para gestión

  // [HU-21]: Estado de los filtros
  Set<DamageLevel> _filterLevels = {};
  DateTimeRange? _filterDateRange;
  double _maxDistanceKm = 10.0; // Radio por defecto para HU-20
  StreamSubscription<Position>? _positionSubscription; // For HU-22 continuous monitoring

  ClassificationState get state => _state;
  SaveState get saveState => _saveState;
  SyncStatus get syncStatus => _syncStatus;
  RoadIncidence? get result => _result;
  String? get errorMessage => _errorMessage;
  String? get warningMessage => _warningMessage;
  int? get georefLatencyMs => _georefLatencyMs;
  String? get selectedImagePath => _selectedImagePath;
  String? get savedDocumentId => _savedDocumentId;
  String get observations => _observations; // HU-07
  ({double latitude, double longitude, String? address})? get userLocation => _userLocation;
  String? get userAddress => _userAddress;
  int get pendingCount => _pendingCount;
  List<Map<String, dynamic>> get pendingReportsList => _pendingReportsList;
  Set<String> get selectedIds => _selectedIds;
  int get selectedCount => _selectedIds.length;
  
  // Getters para filtros
  Set<DamageLevel> get filterLevels => _filterLevels;
  DateTimeRange? get filterDateRange => _filterDateRange;
  double get maxDistanceKm => _maxDistanceKm;

  // [HU-21]: Métodos para actualizar filtros
  void toggleFilterLevel(DamageLevel level) {
    if (_filterLevels.contains(level)) {
      _filterLevels.remove(level);
    } else {
      _filterLevels.add(level);
    }
    notifyListeners();
  }

  void setDateRange(DateTimeRange? range) {
    _filterDateRange = range;
    notifyListeners();
  }

  void setMaxDistance(double distance) {
    _maxDistanceKm = distance;
    notifyListeners();
  }

  void resetFilters() {
    _filterLevels.clear();
    _filterDateRange = null;
    _maxDistanceKm = 10.0;
    notifyListeners();
  }

  // [HU-20]: Cálculo de distancia (Haversine formula)
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 - c((lat2 - lat1) * p) / 2 + 
          c(lat1 * p) * c(lat2 * p) * 
          (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  Future<void> updatePendingCount() async {
    _pendingReportsList = await _localStoragePort.getAllPendingReports();
    _pendingCount = _pendingReportsList.length;
    
    // Limpiar IDs seleccionados que ya no existen
    _selectedIds.retainWhere((id) => _pendingReportsList.any((r) => r['id'] == id));
    
    notifyListeners();
  }

  void toggleSelection(String id) {
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
    } else {
      _selectedIds.add(id);
    }
    notifyListeners();
  }

  void toggleSelectAll() {
    if (_selectedIds.length == _pendingReportsList.length && _pendingReportsList.isNotEmpty) {
      _selectedIds.clear();
    } else {
      _selectedIds.addAll(_pendingReportsList.map((r) => r['id'] as String));
    }
    notifyListeners();
  }

  Future<void> deletePendingReport(String id) async {
    await _localStoragePort.deleteReport(id);
    _selectedIds.remove(id);
    await updatePendingCount();
  }

  Future<void> clearAllPendingReports() async {
    await _localStoragePort.deleteAllReports();
    _selectedIds.clear();
    await updatePendingCount();
  }

  // [HU-16/18]: Sincronización automática de reportes pendientes.
  Future<void> syncPendingReports({List<String>? specificIds}) async {
    if (_syncStatus == SyncStatus.syncing) return; // [HU-18]: Evita duplicidad por clics múltiples

    final allPending = await _localStoragePort.getAllPendingReports();
    final pending = specificIds == null 
        ? allPending 
        : allPending.where((r) => specificIds.contains(r['id'])).toList();

    if (pending.isEmpty) return;

    _syncStatus = SyncStatus.syncing;
    _warningMessage = null;
    _errorMessage = null;
    notifyListeners();

    bool hasItemError = false;
    try {
      for (var report in pending) {
        try {
          // [HU-18]: Validación de ID para evitar errores en el borrado local
          if (report['id'] == null) continue;

          // Robustez en el mapeo de clases
          final damageLevel = DamageLevel.values.firstWhere(
            (e) => e.name.toLowerCase() == report['clase'].toString().toLowerCase() || 
                   e.label.toLowerCase() == report['clase'].toString().toLowerCase(),
            orElse: () => DamageLevel.normal,
          );

          // [HU-18 - Escenario 1]: Sincronización individual
          final resultId = await _saveInspectionUsecase.execute(
            RoadIncidence(
              id: report['id'],
              imagePath: report['imagePath'],
              damageLevel: damageLevel,
              confidence: report['confianza'],
              probabilities: {}, 
              detectedAt: DateTime.parse(report['fechaHora']),
              latitude: report['latitud'],
              longitude: report['longitud'],
              address: report['direccion'],
            ),
            report['imagePath'],
            direccion: report['direccion'],
            observaciones: report['observaciones'],
            isSyncing: true, 
          );

          if (resultId != null && !resultId.startsWith('offline_')) {
            await _localStoragePort.deleteReport(report['id']);
            // [HU-18]: Actualización optimizada de la lista en memoria
            _pendingReportsList.removeWhere((r) => r['id'] == report['id']);
            _pendingCount = _pendingReportsList.length;
            notifyListeners();
          }
        } catch (itemError) {
          hasItemError = true;
          debugPrint('Error en reporte individual ${report['id']}: $itemError');
          // Continuamos con el siguiente reporte del bucle
        }
      }
      _syncStatus = hasItemError ? SyncStatus.error : SyncStatus.completed;
      if (hasItemError && _pendingCount > 0) {
        _errorMessage = 'Sincronización parcial: algunos registros fallaron.';
      }
    } catch (e) {
      _syncStatus = SyncStatus.error;
      _errorMessage = 'Error crítico en el proceso de sincronización';
    }
    await updatePendingCount();
    notifyListeners();
  }

  // [HU-20]: Fetch and set current user location
  Future<void> fetchAndSetCurrentLocation() async {
    _warningMessage = null; // Clear previous warnings
    try {
      final coords = await _locationPort.getCurrentLocation();
      _userLocation = coords;
      _userAddress = coords.address;
      notifyListeners();
    } catch (e) {
      _userLocation = null;
      _userAddress = null;
      _warningMessage = 'No se pudo obtener la ubicación actual. Verifique el GPS y los permisos.';
      notifyListeners();
      debugPrint('Error fetching user location: $e');
    }
  }

  // [HU-21]: Stream de inspecciones filtradas para el mapa
  Stream<List<RoadIncidence>> getFilteredInspectionsStream() {
    return FirebaseFirestore.instance.collection('inspecciones').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        // Convert Firestore data to RoadIncidence
        return RoadIncidence(
          id: doc.id,
          imagePath: data['imagePath'] ?? '',
          damageLevel: DamageLevel.values.firstWhere(
            (e) => e.name.toLowerCase() == data['clase'].toString().toLowerCase(),
            orElse: () => DamageLevel.normal,
          ),
          confidence: (data['confianza'] as num?)?.toDouble() ?? 0.0,
          probabilities: {}, // Not directly stored in Firestore for now, or needs mapping
          detectedAt: (data['fechaHora'] as Timestamp).toDate(),
          latitude: (data['latitud'] as num?)?.toDouble(),
          longitude: (data['longitud'] as num?)?.toDouble(),
          address: data['direccion'],
          observations: data['observaciones'],
        );
      }).where((incidence) {
        // Apply filters
        bool matches = true;

        // Filter by DamageLevel (HU-21)
        if (_filterLevels.isNotEmpty && !(_filterLevels.contains(incidence.damageLevel))) {
          matches = false;
        }

        // Filter by DateRange (HU-21)
        if (_filterDateRange != null) {
          final incidenceDate = incidence.detectedAt;
          if (incidenceDate.isBefore(_filterDateRange!.start) || incidenceDate.isAfter(_filterDateRange!.end.add(const Duration(days: 1)))) {
            matches = false;
          }
        }

        // Filter by Proximity (HU-20)
        if (_userLocation != null && _maxDistanceKm > 0 && incidence.latitude != null && incidence.longitude != null) {
          final distance = calculateDistance(
            _userLocation!.latitude,
            _userLocation!.longitude,
            incidence.latitude!,
            incidence.longitude!,
          );
          if (distance > _maxDistanceKm) {
            matches = false;
          }
        }

        return matches;
      }).toList();
    });
  }

  // [HU-22]: Continuous location monitoring for alerts
  void _startLocationMonitoring() {
    // Check for permissions and service status first
    _locationPort.getCurrentLocation().then((_) {
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Update every 10 meters
        ),
      ).listen((Position position) {
        _userLocation = (latitude: position.latitude, longitude: position.longitude, address: null); // Address can be reverse geocoded if needed
        _userAddress = null; // Clear address, will be updated on demand or from full fetch
        _checkForCriticalIncidents(); // New method for alert logic
        notifyListeners();
      }, onError: (e) {
        debugPrint('Error in position stream: $e');
        _warningMessage = 'No se pudo mantener la ubicación en tiempo real para alertas.';
        notifyListeners();
      });
    }).catchError((e) {
      debugPrint('Initial location check failed for monitoring: $e');
      _warningMessage = 'No se pudo iniciar el monitoreo de ubicación para alertas.';
      notifyListeners();
    });
  }

  void setImagePath(String path) {
    _selectedImagePath = path;
    _state = ClassificationState.idle;
    _saveState = SaveState.idle;
    _warningMessage = null;
    _result = null;
    _savedDocumentId = null;
    _observations = '';
    notifyListeners();
  }

  void setObservations(String value) {
    _observations = value;
    notifyListeners();
  }

  Future<void> classify() async {
    if (_selectedImagePath == null) return;

    _state = ClassificationState.loading;
    _errorMessage = null;
    _warningMessage = null;
    _georefLatencyMs = null;
    notifyListeners();
    // [PMV1 - HU-08 - Escenario 1]: Inicio del procesamiento automático de la imagen.

    double? lat, lng;
    String? address;
    try {
      // [UC-IA-12 - Escenario 1]: Medición de latencia para validación de PoC.
      final stopwatch = Stopwatch()..start();
      final coords = await _locationPort.getCurrentLocation();
      stopwatch.stop();
      _georefLatencyMs = stopwatch.elapsed.inMilliseconds;

      lat = coords.latitude;
      lng = coords.longitude;
      address = coords.address;
      debugPrint('POC UC-IA-12: Georreferenciación exitosa en ${stopwatch.elapsed.inMilliseconds}ms');
    } catch (e) {
      // [HU-06/07/17]: Si falla la ubicación, instruimos al usuario a usar las observaciones.
      if (e.toString().contains('TIMEOUT_SIGNAL')) {
        _warningMessage = 'Señal GPS débil. Por seguridad, escribe la dirección en "Observaciones".';
      } else {
        _warningMessage = 'Ubicación no disponible. Verifique que el GPS esté activo en ajustes o escribe la dirección en "Observaciones" para ubicar el bache.';
      }
      debugPrint('POC UC-IA-12: Error/Timeout en georreferenciación: $e');
    }

    try {
      // [PMV1 - HU-09 - Escenario 1]: El modelo identifica la presencia de anomalías.
      final aiResult = await _classifyImagePort.execute(_selectedImagePath!);
      
      // Asociamos los datos de ubicación a la entidad resultante
      _result = _applyLocation(aiResult, lat, lng, address);
      _state = ClassificationState.success;
    } on AiClassificationException catch (e) {
      _errorMessage = e.userMessage;
      _state = ClassificationState.error;
    } catch (e) {
      // [PMV1 - HU-08 - Escenario 2]: La imagen no puede ser interpretada o procesada.
      _errorMessage = 'Error al clasificar: $e';
      _state = ClassificationState.error;
    }

    notifyListeners();
  }

  /// [HU-14 - Escenario 1]: Registro manual cuando no hay detección automática.
  Future<void> startManualRegistration() async {
    if (_selectedImagePath == null) return;

    _state = ClassificationState.loading;
    _errorMessage = null;
    _warningMessage = null;
    notifyListeners();

    double? lat, lng;
    String? address;
    try {
      final stopwatch = Stopwatch()..start();
      final coords = await _locationPort.getCurrentLocation();
      stopwatch.stop();
      
      lat = coords.latitude;
      lng = coords.longitude;
      address = coords.address;
      debugPrint('POC UC-IA-12 (Manual): Georreferenciación exitosa en ${stopwatch.elapsed.inMilliseconds}ms');
    } catch (e) {
      _warningMessage = 'Ubicación no detectada. Indica la dirección en el campo "Observaciones".';
    }

    // [HU-14 - Escenario 1]: El sistema crea una incidencia base (Manual) para que el usuario complete la información.
    _result = RoadIncidence(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      imagePath: _selectedImagePath!,
      damageLevel: DamageLevel.normal, // Valor por defecto para ser editado
      confidence: 1.0,
      probabilities: {DamageLevel.normal: 1.0, DamageLevel.leve: 0.0, DamageLevel.danado: 0.0},
      detectedAt: DateTime.now(),
      latitude: lat,
      longitude: lng,
      address: address,
    );
    
    _state = ClassificationState.success;
    notifyListeners();
  }

  RoadIncidence _applyLocation(RoadIncidence base, double? lat, double? lng, String? address) {
    return RoadIncidence(
      id: base.id,
      imagePath: base.imagePath,
      gradcamPath: base.gradcamPath,
      damageLevel: base.damageLevel,
      confidence: base.confidence,
      probabilities: base.probabilities,
      detectedAt: base.detectedAt,
      latitude: lat,
      longitude: lng,
      address: address ?? base.address, // [HU-07]: Priorizar la dirección nueva obtenida
      observations: base.observations, // HU-07: Preservar las observaciones existentes
    );
  }

  void updateDamageLevel(DamageLevel newLevel) {
    if (_result != null) {
      // [HU-13]: Generamos un nuevo mapa de probabilidades para que la UI sea consistente con la edición humana.
      // El nivel seleccionado por el usuario tendrá 1.0 (100%) y los demás 0.0.
      final Map<DamageLevel, double> updatedProbabilities = {
        for (var level in DamageLevel.values) level: level == newLevel ? 1.0 : 0.0,
      };

      // [PMV1 - HU-13 - Escenario 1]: El usuario edita el resultado (Validación manual).
      _result = RoadIncidence(
        id: _result!.id,
        imagePath: _result!.imagePath,
        gradcamPath: _result!.gradcamPath,
        damageLevel: newLevel,
        confidence: 1.0, // Al ser validación manual, la confianza se asume total.
        probabilities: updatedProbabilities,
        detectedAt: _result!.detectedAt,
        latitude: _result!.latitude,
        longitude: _result!.longitude,
        address: _result!.address,
        observations: _observations, // HU-13: Al editar, vinculamos las observaciones actuales
      );
      _saveState = SaveState.idle; // Resetear estado de guardado si se edita
      notifyListeners();
    }
  }

  Future<void> saveInspection() async {
    if (_result == null || _selectedImagePath == null || _saveState == SaveState.saving) return;

    // [HU-07/14 - Escenario 2]: Validación de información mínima obligatoria.
    if (_selectedImagePath!.isEmpty) {
      _errorMessage = 'Se requiere una evidencia fotográfica para registrar la incidencia.';
      _saveState = SaveState.error;
      notifyListeners();
      return;
    }

    // [NUEVO]: Intento de recuperación de ubicación si falta al momento de registrar.
    if (_result!.latitude == null || _result!.longitude == null) {
      _saveState = SaveState.saving; // Mostramos indicador de carga mientras reintenta
      notifyListeners();

      try {
        final stopwatch = Stopwatch()..start();
        final coords = await _locationPort.getCurrentLocation();
        stopwatch.stop();
        _georefLatencyMs = stopwatch.elapsed.inMilliseconds;

        _result = _applyLocation(_result!, coords.latitude, coords.longitude, coords.address);
        _warningMessage = 'Ubicación recuperada exitosamente.'; // Escenario 2: Failsafe exitoso
      } catch (e) {
        // [HU-17/14]: No bloqueamos el registro local si falla el GPS. 
        // Informamos al usuario que la precisión será baja, pero permitimos guardar.
        _warningMessage = 'Sin ubicación GPS. Por seguridad agrega en "Observaciones".';
        debugPrint('Fallo de GPS en guardado: Procediendo para permitir registro local.');
      }
    }

    // [HU-13 - Escenario 1]: El usuario confirma el resultado y procede al registro definitivo.
    _saveState = SaveState.saving;
    _errorMessage = null;
    _warningMessage = null;
    notifyListeners();

    try {
      // Si no hay observaciones, usamos el valor por defecto.
      final String finalObservations = _observations.trim().isEmpty ? 'Sin observación adicional' : _observations;

      _savedDocumentId = await _saveInspectionUsecase.execute(
        _result!,
        _result!.imagePath,
        direccion: _result!.address ?? 'Dirección vía GPS no disponible', 
        observaciones: finalObservations,
      );
      
      if (_savedDocumentId!.startsWith('offline_')) {
        // [HU-17]: Feedback de guardado local exitoso.
        _saveState = SaveState.saved;
        await updatePendingCount();
      } else {
        _saveState = SaveState.saved;
      }
    } catch (e) {
      // [HU-17 Escenario 2]: Manejo de error de almacenamiento local
      _errorMessage = 'No fue posible almacenar la incidencia. Verifique el espacio disponible.';
      _saveState = SaveState.error;
    }

    notifyListeners();
  }

  // [HU-22]: Check for critical incidents nearby
  Future<void> _checkForCriticalIncidents() async {
    // Evitar consultas si no hay ubicación o si el usuario aún no se ha autenticado
    if (_userLocation == null || FirebaseAuth.instance.currentUser == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('inspecciones')
        .where('uid', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
        .get();
    final incidents = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return RoadIncidence(
        id: doc.id,
        imagePath: data['imagePath'] ?? '',
        damageLevel: DamageLevel.values.firstWhere(
          (e) => e.name.toLowerCase() == data['clase'].toString().toLowerCase(),
          orElse: () => DamageLevel.normal,
        ),
        confidence: (data['confianza'] as num?)?.toDouble() ?? 0.0,
        probabilities: {},
        detectedAt: (data['fechaHora'] as Timestamp).toDate(),
        latitude: (data['latitud'] as num?)?.toDouble(),
        longitude: (data['longitud'] as num?)?.toDouble(),
        address: data['direccion'],
        observations: data['observaciones'],
      );
    }).toList();

    final roadSafetyService = RoadSafetyService(); // Assuming this can be instantiated or injected

    for (var incidence in incidents) {
      if (incidence.latitude != null && incidence.longitude != null) {
        final distance = calculateDistance(
          _userLocation!.latitude,
          _userLocation!.longitude,
          incidence.latitude!,
          incidence.longitude!,
        );

        // Define a threshold for "aproximarse a zonas" (e.g., 500 meters)
        if (distance < GeoThresholds.proximityAlertRadiusKm) { // 0.5 km = 500 meters
          if (roadSafetyService.shouldTriggerEmergencyAlert(incidence.damageLevel, incidence.confidence)) {
            // [HU-22 - Escenario 1]: Trigger local notification
            // Placeholder for notification logic
            debugPrint('ALERTA: Incidencia crítica cercana detectada: ${incidence.id} a ${distance.toStringAsFixed(2)} km');
            // TODO: Implement actual local notification using flutter_local_notifications
            // Example: _notificationService.showNotification(
            //   id: incidence.id.hashCode,
            //   title: '¡Alerta Vial Crítica!',
            //   body: 'Te aproximas a una zona con daño ${incidence.damageLevel.label} (${incidence.address ?? 'ubicación desconocida'}).',
            // );
          }
        }
      }
    }
  }

  void reset() {
    _state = ClassificationState.idle;
    _saveState = SaveState.idle;
    // [HU-13 - Escenario 1]: El usuario descarta la detección actual para iniciar una nueva.
    _result = null;
    _errorMessage = null;
    _warningMessage = null;
    _selectedImagePath = null;
    _georefLatencyMs = null;
    _savedDocumentId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }
}