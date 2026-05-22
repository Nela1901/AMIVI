import 'dart:async';

abstract class LocationPort {
  /// Obtiene las coordenadas actuales. 
  /// Lanza una excepción si el GPS está desactivado o no hay permisos.
  Future<({double latitude, double longitude, String? address})> getCurrentLocation();
}