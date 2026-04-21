import '../../domain/entities/road_incidence.dart';
import '../ports/input/classify_image_port.dart';
import '../ports/output/ai_detector_port.dart';

class ClassifyRoadImageUsecase implements ClassifyImagePort {
  final AiDetectorPort _aiDetectorPort;

  ClassifyRoadImageUsecase(this._aiDetectorPort);

  @override
  Future<RoadIncidence> execute(String imagePath) async {
    if (imagePath.isEmpty) {
      throw ArgumentError('La ruta de la imagen no puede estar vacía.');
    }
    return await _aiDetectorPort.classifyImage(imagePath);
  }
}