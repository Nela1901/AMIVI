import '../valueobjects/damage_level.dart';
import '../constants/ai_thresholds.dart';

/// Nivel de prioridad calculado para la intervención vial
enum UrgencyLevel { critical, high, moderate, low, verificationRequired }

/// Servicio de Dominio que encapsula la lógica de evaluación de riesgos viales.
/// Cumple con la Arquitectura Hexagonal al centralizar reglas de negocio 
/// que dependen de múltiples factores del dominio.
class RoadSafetyService {
  
  /// Calcula el nivel de urgencia basado en la severidad detectada y la confianza de la IA.
  UrgencyLevel determineUrgency(DamageLevel level, double confidence) {
    // Si la confianza es muy baja, independientemente del daño, requiere verificación humana
    if (confidence < AiThresholds.minimumConfidenceThreshold) {
      return UrgencyLevel.verificationRequired;
    }

    switch (level) {
      case DamageLevel.danado:
        // Daño severo con alta confianza es crítico
        return confidence > AiThresholds.emergencyAlertThreshold ? UrgencyLevel.critical : UrgencyLevel.high;
      
      case DamageLevel.leve:
        // Daño leve es moderado si estamos seguros, si no, es bajo
        return confidence > AiThresholds.moderateDamageThreshold ? UrgencyLevel.moderate : UrgencyLevel.low;
      
      case DamageLevel.normal:
        return UrgencyLevel.low;
    }
  }

  /// Determina si una incidencia debe disparar una alerta inmediata a las autoridades (HU-29)
  bool shouldTriggerEmergencyAlert(DamageLevel level, double confidence) {
    final urgency = determineUrgency(level, confidence);
    return urgency == UrgencyLevel.critical;
  }
}