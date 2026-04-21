import '../../../domain/entities/road_incidence.dart';

abstract interface class ClassifyImagePort {
  Future<RoadIncidence> execute(String imagePath);
}