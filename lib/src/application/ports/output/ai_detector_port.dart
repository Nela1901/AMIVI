import '../../../domain/entities/road_incidence.dart';

abstract interface class AiDetectorPort {
  Future<RoadIncidence> classifyImage(String imagePath);
}