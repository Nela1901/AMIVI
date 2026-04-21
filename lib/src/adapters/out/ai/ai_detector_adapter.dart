import 'dart:io';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../../domain/entities/road_incidence.dart';
import '../../../domain/valueobjects/damage_level.dart';
import '../../../application/ports/output/ai_detector_port.dart';

class AiDetectorAdapter implements AiDetectorPort {
  static const String _modelPath =
      'lib/src/adapters/out/ai/models/modelo_vial_correcto.tflite';

  Interpreter? _interpreter;
  final _uuid = const Uuid();

  Future<void> _loadModel() async {
    if (_interpreter != null) return;
    final modelData = await rootBundle.load(_modelPath);
    final buffer = modelData.buffer.asUint8List();
    _interpreter = Interpreter.fromBuffer(buffer);
  }

  // Copia la imagen a directorio temporal y devuelve la ruta permanente
  Future<String> _copyToTemp(String imagePath) async {
    final tempDir = await getTemporaryDirectory();
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(imagePath)}';
    final tempPath = '${tempDir.path}/$fileName';
    await File(imagePath).copy(tempPath);
    return tempPath;
  }

  @override
  Future<RoadIncidence> classifyImage(String imagePath) async {
    await _loadModel();

    // Copiar imagen a directorio temporal para evitar PathNotFoundException
    final safePath = await _copyToTemp(imagePath);

    // Leer y preprocesar imagen
    final imageFile = File(safePath);
    final rawBytes = await imageFile.readAsBytes();
    img.Image? image = img.decodeImage(rawBytes);
    if (image == null) throw Exception('No se pudo decodificar la imagen.');

    // Redimensionar a 224x224
    image = img.copyResize(image, width: 224, height: 224);

    // Preprocesar: píxeles en rango [0, 255]
    final input = List.generate(
      1,
      (_) => List.generate(
        224,
        (y) => List.generate(
          224,
          (x) {
            final pixel = image!.getPixel(x, y);
            final r = pixel.r.toDouble();
            final g = pixel.g.toDouble();
            final b = pixel.b.toDouble();
            return [r, g, b];
          },
        ),
      ),
    );

    // Salida del modelo
    final output = List.filled(1 * 3, 0.0).reshape([1, 3]);
    _interpreter!.run(input, output);

    final probabilities = List<double>.from(output[0] as List);

    final Map<DamageLevel, double> probMap = {
      DamageLevel.danado: probabilities[0],
      DamageLevel.leve: probabilities[1],
      DamageLevel.normal: probabilities[2],
    };

    int maxIndex = 0;
    double maxProb = probabilities[0];
    for (int i = 1; i < probabilities.length; i++) {
      if (probabilities[i] > maxProb) {
        maxProb = probabilities[i];
        maxIndex = i;
      }
    }

    final DamageLevel resultLevel = switch (maxIndex) {
      0 => DamageLevel.danado,
      1 => DamageLevel.leve,
      _ => DamageLevel.normal,
    };

    return RoadIncidence(
      id: _uuid.v4(),
      imagePath: safePath, // ← ruta de la copia temporal
      damageLevel: resultLevel,
      confidence: maxProb,
      probabilities: probMap,
      detectedAt: DateTime.now(),
    );
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}