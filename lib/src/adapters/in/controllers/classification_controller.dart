import 'package:flutter/material.dart';
import '../../../application/ports/input/classify_image_port.dart';
import '../../../application/usecases/save_inspection_usecase.dart';
import '../../../domain/entities/road_incidence.dart';
import '../../../domain/valueobjects/damage_level.dart';


enum ClassificationState { idle, loading, success, error }
enum SaveState { idle, saving, saved, error }

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

    try {
      _result = await _classifyImagePort.execute(_selectedImagePath!);
      _state = ClassificationState.success;
    } catch (e) {
      _errorMessage = 'Error al clasificar la imagen: $e';
      _state = ClassificationState.error;
    }

    notifyListeners();
  }

  /// Permite editar manualmente el resultado (HU-13)
  void updateDamageLevel(DamageLevel newLevel) {
    if (_result != null) {
      _result = RoadIncidence(
        id: _result!.id,
        imagePath: _result!.imagePath,
        gradcamPath: _result!.gradcamPath,
        damageLevel: newLevel,
        confidence: 1.0, // Al ser manual, la confianza es total
        probabilities: _result!.probabilities,
        detectedAt: _result!.detectedAt,
      );
      _saveState = SaveState.idle; // Resetear estado de guardado si se edita
      notifyListeners();
    }
  }

  Future<void> saveInspection() async {
    if (_result == null || _selectedImagePath == null) return;

    _saveState = SaveState.saving;
    _errorMessage = null;
    notifyListeners();

    try {
      _savedDocumentId = await _saveInspectionUsecase.execute(
        _result!,
        _selectedImagePath!,
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
    _result = null;
    _errorMessage = null;
    _selectedImagePath = null;
    _savedDocumentId = null;
    notifyListeners();
  }
}