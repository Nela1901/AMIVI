import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/foundation.dart';
import '../../../application/ports/output/location_port.dart';

class GeolocatorAdapter implements LocationPort {
  @override
  Future<({double latitude, double longitude, String? address})> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // [HU-06 - Escenario 2]: Given que el GPS del dispositivo está desactivado
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('La ubicación (GPS) está desactivada.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // [HU-06 - Escenario 2]: Given que no se otorgaron permisos de ubicación
        throw Exception('Permisos de ubicación denegados.');
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Los permisos de ubicación están denegados permanentemente.');
    }

    Position? position;
    try {
      // [UC-IA-12]: Intento de obtener ubicación precisa (KPI: < 3s)
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 3),
        ),
      );
    } on TimeoutException {
      // [HU-17/18]: Si no hay señal (offline/techo), usamos la última ubicación conocida como respaldo.
      // Esto evita que el usuario quede bloqueado en zonas rurales o interiores.
      position = await Geolocator.getLastKnownPosition();
      
      if (position == null) {
        // Si tampoco hay ubicación previa, lanzamos un error específico para el controlador.
        throw Exception('TIMEOUT_SIGNAL');
      }
      debugPrint('Usando ubicación de respaldo (Last Known Position) por falta de señal');
    } catch (e) {
      rethrow;
    }

    // [HU-07]: Implementación de Reverse Geocoding para obtener el nombre de la calle y localidad.
    String? address;
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude, 
        position.longitude
      );
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        address = "${p.street}, ${p.locality}";
      }
    } catch (e) {
      debugPrint('Error en Geocoding: $e');
    }

    return (latitude: position.latitude, longitude: position.longitude, address: address);
  }
}