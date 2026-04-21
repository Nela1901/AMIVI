import 'package:geolocator/geolocator.dart';
import '../../domain/entities/road_incidence.dart';
import '../ports/output/save_inspection_port.dart';

class SaveInspectionUsecase {
  final SaveInspectionPort _saveInspectionPort;

  SaveInspectionUsecase(this._saveInspectionPort);

  Future<String> execute(RoadIncidence incidence, String imagePath) async {
    final position = await _getCurrentPosition();
    return await _saveInspectionPort.saveInspection(
      incidence: incidence,
      imagePath: imagePath,
      latitud: position.latitude,
      longitud: position.longitude,
    );
  }

  Future<Position> _getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('El servicio de ubicación está desactivado.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Permiso de ubicación denegado.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Permiso de ubicación denegado permanentemente.');
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }
}