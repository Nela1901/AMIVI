import 'dart:io';
import '../../domain/entities/road_incidence.dart';
import '../ports/output/save_inspection_port.dart';
import '../ports/output/local_storage_port.dart';

class SaveInspectionUsecase {
  final SaveInspectionPort _saveInspectionPort;
  final LocalStoragePort _localStoragePort;

  SaveInspectionUsecase(this._saveInspectionPort, this._localStoragePort);

  Future<String> execute(RoadIncidence incidence, String imagePath, {String? direccion, String? observaciones, bool isSyncing = false}) async {
    try {
      // Intentamos verificar conexión (simple lookup a Google)
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        // [HU-16 - Escenario 1]: Sincronización exitosa con la nube.
        return await _saveInspectionPort.saveInspection(
          incidence: incidence,
          imagePath: imagePath,
          latitud: incidence.latitude,
          longitud: incidence.longitude,
          direccion: direccion,
          observaciones: observaciones,
        );
      }
      throw const SocketException('Sin conexión');
    } catch (_) {
      // [HU-18]: Si estamos sincronizando y falla, lanzamos el error para no duplicar el registro local.
      if (isSyncing) rethrow;

      // [HU-17 - Escenario 1]: Registro inicial sin internet.
      await _localStoragePort.saveOffline(
        incidence,
        imagePath,
        direccion: direccion,
        observaciones: observaciones
      );
      return 'offline_${incidence.id}';
    }
  }
}