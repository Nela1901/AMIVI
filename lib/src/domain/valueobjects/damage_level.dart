enum DamageLevel {
  normal,
  leve,
  danado;

  String get label {
    switch (this) {
      case DamageLevel.normal:
        return 'Normal';
      case DamageLevel.leve:
        return 'Leve';
      case DamageLevel.danado:
        return 'Dañado';
    }
  }

  String get description {
    switch (this) {
      case DamageLevel.normal:
        return 'La vía se encuentra en buen estado. No requiere intervención.';
      case DamageLevel.leve:
        return 'Se detectan daños leves. Requiere seguimiento preventivo.';
      case DamageLevel.danado:
        return 'Daño significativo detectado. Requiere intervención inmediata.';
    }
  }
}