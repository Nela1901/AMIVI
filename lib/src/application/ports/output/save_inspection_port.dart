import '../../../domain/entities/road_incidence.dart';

abstract interface class SaveInspectionPort {
  Future<String> saveInspection({
    required RoadIncidence incidence,
    required String imagePath,
    double? latitud,
    double? longitud,
    String? direccion,
    String? observaciones,
  });
}