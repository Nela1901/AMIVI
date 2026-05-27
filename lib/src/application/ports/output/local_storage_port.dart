import '../../../domain/entities/road_incidence.dart';

abstract interface class LocalStoragePort {
  // [HU-17]: Guarda el reporte localmente cuando no hay internet.
  Future<void> saveOffline(RoadIncidence incidence, String imagePath, {String? direccion, String? observaciones});
  
  // [HU-18]: Recupera reportes para sincronización posterior.
  Future<List<Map<String, dynamic>>> getAllPendingReports();
  
  Future<void> deleteReport(String id);

  Future<void> deleteAllReports();
}