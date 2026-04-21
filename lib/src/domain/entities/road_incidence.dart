import '../valueobjects/damage_level.dart';

class RoadIncidence {
  final String id;
  final String imagePath;
  final DamageLevel damageLevel;
  final double confidence;
  final Map<DamageLevel, double> probabilities;
  final DateTime detectedAt;

  const RoadIncidence({
    required this.id,
    required this.imagePath,
    required this.damageLevel,
    required this.confidence,
    required this.probabilities,
    required this.detectedAt,
  });

  bool get requiresIntervention => damageLevel == DamageLevel.danado;
  bool get requiresMonitoring => damageLevel == DamageLevel.leve;
}