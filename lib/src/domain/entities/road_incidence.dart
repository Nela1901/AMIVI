import '../valueobjects/damage_level.dart';

class RoadIncidence {
  final String id;
  final String imagePath;
  final String? gradcamPath; // ← HU-10: ruta de la imagen con mapa de calor
  final DamageLevel damageLevel;
  final double confidence;
  final Map<DamageLevel, double> probabilities;
  final DateTime detectedAt;

  const RoadIncidence({
    required this.id,
    required this.imagePath,
    this.gradcamPath, // ← opcional, null si Grad-CAM falla (Escenario 2)
    required this.damageLevel,
    required this.confidence,
    required this.probabilities,
    required this.detectedAt,
  });

  bool get requiresIntervention => damageLevel == DamageLevel.danado;
  bool get requiresMonitoring => damageLevel == DamageLevel.leve;
}