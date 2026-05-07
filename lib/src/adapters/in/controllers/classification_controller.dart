import 'package:flutter/material.dart';
import '../../../application/ports/input/classify_image_port.dart';
import '../../../application/usecases/save_inspection_usecase.dart';
import '../../../domain/entities/road_incidence.dart';
import '../../../domain/valueobjects/damage_level.dart';

//DEFINICION DE ENUMS PARA LOS ESTADOS DE CLASIFICACIÓN Y GUARDADO,
//PERMITE A LA UI SABER CUANDO MOSTRAR CARGANDO, RESULTADOS, O MENSAJES DE ERROR.
enum ClassificationState { idle, loading, success, error }
enum SaveState { idle, saving, saved, error }

//HABLA CON EL DOMINIO PARA CLASIFICAR LA IMAGEN Y GUARDAR LA INSPECCIÓN, 
//MANEJA LOS ESTADOS DE CARGA Y ERROR, Y NOTIFICA A LA UI CUANDO HAY CAMBIOS
class ClassificationController extends ChangeNotifier {
  final ClassifyImagePort _classifyImagePort;
  final SaveInspectionUsecase _saveInspectionUsecase;

  ClassificationController(
    this._classifyImagePort,
    this._saveInspectionUsecase,
  );

  ClassificationState _state = ClassificationState.idle;
  SaveState _saveState = SaveState.idle;
  RoadIncidence? _result;
  String? _errorMessage;
  String? _selectedImagePath;
  String? _savedDocumentId;

  ClassificationState get state => _state;
  SaveState get saveState => _saveState;
  RoadIncidence? get result => _result;
  String? get errorMessage => _errorMessage;
  String? get selectedImagePath => _selectedImagePath;
  String? get savedDocumentId => _savedDocumentId;

  void setImagePath(String path) {
    _selectedImagePath = path;
    _state = ClassificationState.idle;
    _saveState = SaveState.idle;
    _result = null;
    _savedDocumentId = null;
    notifyListeners();
  }

  Future<void> classify() async {
    if (_selectedImagePath == null) return;

    _state = ClassificationState.loading;
    _errorMessage = null;
    notifyListeners();
    // [PMV1 - HU-08 - Escenario 1]: Inicio del procesamiento automático de la imagen.

    try {
      // [PMV1 - HU-09 - Escenario 1]: El modelo identifica la presencia de anomalías.
      _result = await _classifyImagePort.execute(_selectedImagePath!);
      _state = ClassificationState.success;
    } catch (e) {
      // [PMV1 - HU-08 - Escenario 2]: La imagen no puede ser interpretada o procesada.
      _errorMessage = 'Error al clasificar la imagen: $e';
      _state = ClassificationState.error;
    }

    notifyListeners();
  }

  void updateDamageLevel(DamageLevel newLevel) {
    if (_result != null) {
      // [PMV1 - HU-13 - Escenario 1]: El usuario edita el resultado (Validación manual).
      _result = RoadIncidence(
        id: _result!.id,
        imagePath: _result!.imagePath,
        gradcamPath: _result!.gradcamPath,
        damageLevel: newLevel,
        confidence: 1.0, // Al ser validación manual, la confianza se asume total.
        probabilities: _result!.probabilities,
        detectedAt: _result!.detectedAt,
      );
      _saveState = SaveState.idle; // Resetear estado de guardado si se edita
      notifyListeners();
    }
  }

  Future<void> saveInspection() async {
    if (_result == null || _selectedImagePath == null) return;

    // [PMV1 - HU-13 - Escenario 1]: El usuario confirma y procede al registro.
    _saveState = SaveState.saving;
    _errorMessage = null;
    notifyListeners();

    try {
      _savedDocumentId = await _saveInspectionUsecase.execute(
        _result!,
        _result!.imagePath,
      );
      _saveState = SaveState.saved;
    } catch (e) {
      _errorMessage = 'Error al registrar inspección: $e';
      _saveState = SaveState.error;
    }

    notifyListeners();
  }

  void reset() {
    _state = ClassificationState.idle;
    _saveState = SaveState.idle;
    // [PMV1 - HU-13 - Escenario 1]: El usuario descarta la detección actual.
    _result = null;
    _errorMessage = null;
    _selectedImagePath = null;
    _savedDocumentId = null;
    notifyListeners();
  }
}