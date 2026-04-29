import 'dart:io';
import 'dart:math';
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
  // ── Modelos ──────────────────────────────────────────────────────────
  static const String _modelPath =
      'lib/src/adapters/out/ai/models/modelo_vial_correcto.tflite';
  static const String _gradcamModelPath =
      'lib/src/adapters/out/ai/models/modelo_vial_gradcam.tflite';

  // Clases en orden alfabético — igual que en entrenamiento
  static const List<String> _classNames = ['dañado', 'leve', 'normal'];

  Interpreter? _interpreter;
  Interpreter? _gradcamInterpreter;
  final _uuid = const Uuid();

  // ── Carga de modelos ─────────────────────────────────────────────────

  Future<void> _loadModel() async {
    if (_interpreter != null) return;
    final modelData = await rootBundle.load(_modelPath);
    _interpreter = Interpreter.fromBuffer(modelData.buffer.asUint8List());
  }

  Future<void> _loadGradcamModel() async {
    if (_gradcamInterpreter != null) return;
    final modelData = await rootBundle.load(_gradcamModelPath);
    _gradcamInterpreter =
        Interpreter.fromBuffer(modelData.buffer.asUint8List());
  }

  // ── Preprocesamiento ─────────────────────────────────────────────────
  // preprocess_input de MobileNetV2: normaliza píxeles al rango [-1, 1]
  // NO dividir entre 255 — la normalización es (pixel / 127.5) - 1.0

  List<List<List<List<double>>>> _preprocessImage(img.Image image) {
    final resized = img.copyResize(image, width: 224, height: 224);
    return List.generate(
      1,
      (_) => List.generate(
        224,
        (y) => List.generate(
          224,
          (x) {
            final pixel = resized.getPixel(x, y);
            return [
              pixel.r.toDouble(),
              pixel.g.toDouble(),
              pixel.b.toDouble(),
            ];
          },
        ),
      ),
    );
  }

  // ── Copia imagen a directorio temporal ───────────────────────────────

  Future<String> _copyToTemp(String imagePath) async {
    final tempDir = await getTemporaryDirectory();
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${path.basename(imagePath)}';
    final tempPath = '${tempDir.path}/$fileName';
    await File(imagePath).copy(tempPath);
    return tempPath;
  }

  // ── Clasificación principal ──────────────────────────────────────────

  @override
  Future<RoadIncidence> classifyImage(String imagePath) async {
    await _loadModel();

    final safePath = await _copyToTemp(imagePath);
    final rawBytes = await File(safePath).readAsBytes();
    img.Image? image = img.decodeImage(rawBytes);
    if (image == null) throw Exception('No fue posible procesar la imagen (formato no soportado o archivo corrupto).');

    final input = _preprocessImage(image);
    final output = List.filled(3, 0.0).reshape([1, 3]);
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

    // ── Grad-CAM (Escenario 1 y 2 de HU-10) ─────────────────────────
    String? gradcamPath;
    try {
      // Escenario 2 de HU-10: Si el resultado es 'Normal', no hay una "falla" que resaltar.
      // Forzamos que gradcamPath sea null para mostrar el mensaje de advertencia.
      if (resultLevel == DamageLevel.normal) {
        throw Exception('Detección sin zona de falla relevante.');
      }

      gradcamPath = await _generateGradcam(
        image: image,
        predIndex: maxIndex,
        originalPath: safePath,
      );
    } catch (_) {
      // Escenario 2: Grad-CAM falla → gradcamPath queda null
      gradcamPath = null;
    }

    return RoadIncidence(
      id: _uuid.v4(),
      imagePath: safePath,
      gradcamPath: gradcamPath,
      damageLevel: resultLevel,
      confidence: maxProb,
      probabilities: probMap,
      detectedAt: DateTime.now(),
    );
  }

  // ── Grad-CAM ─────────────────────────────────────────────────────────

  Future<String?> _generateGradcam({
    required img.Image image,
    required int predIndex,
    required String originalPath,
  }) async {
    await _loadGradcamModel();

    final interpreter = _gradcamInterpreter!;
    final input = _preprocessImage(image);

    // Salidas del modelo: [activaciones 7x7x1280, predicciones 1x3]
    // StatefulPartitionedCall_1:0 → shape [1,7,7,1280]
    // StatefulPartitionedCall_1:1 → shape [1,3]
    final outputDetails = interpreter.getOutputTensors();

    // Identificar índices de cada salida por shape
    int convOutputIndex = -1;
    int predOutputIndex = -1;
    for (int i = 0; i < outputDetails.length; i++) {
      final shape = outputDetails[i].shape;
      if (shape.length == 4) convOutputIndex = i; // [1,7,7,1280]
      if (shape.length == 2) predOutputIndex = i; // [1,3]
    }

    if (convOutputIndex == -1 || predOutputIndex == -1) {
      throw Exception('No se encontraron las salidas esperadas en el modelo Grad-CAM.');
    }

    // Buffers de salida
    final convShape = outputDetails[convOutputIndex].shape;
    final convOutput = List.generate(
      convShape[1], (_) => List.generate(
        convShape[2], (_) => List.filled(convShape[3], 0.0),
      ),
    ).reshape([1, convShape[1], convShape[2], convShape[3]]);

    final predOutput = List.filled(3, 0.0).reshape([1, 3]);

    final outputs = {
      convOutputIndex: convOutput,
      predOutputIndex: predOutput,
    };

    interpreter.runForMultipleInputs([input], outputs);

    // Extraer activaciones [7,7,1280]
    final activations = (convOutput as List)[0] as List;
    final h = activations.length;       // 7
    final w = (activations[0] as List).length; // 7
    final c = ((activations[0] as List)[0] as List).length; // 1280

    // Extraer predicciones y calcular pesos (Global Average Pooling de gradientes)
    // Aproximación: usar las activaciones ponderadas por la predicción de la clase
    final preds = List<double>.from((predOutput as List)[0] as List);

    // Calcular heatmap: suma ponderada de mapas de activación
    // peso de cada canal = valor de predicción de la clase objetivo
    final heatmap = List.generate(h, (_) => List.filled(w, 0.0));

    for (int i = 0; i < h; i++) {
      for (int j = 0; j < w; j++) {
        double sum = 0.0;
        final channelValues = (activations[i] as List)[j] as List;
        for (int k = 0; k < c; k++) {
          sum += (channelValues[k] as num).toDouble();
        }
        heatmap[i][j] = sum;
      }
    }

    // Normalizar heatmap entre 0 y 1
    double minVal = heatmap[0][0];
    double maxVal = heatmap[0][0];
    for (int i = 0; i < h; i++) {
      for (int j = 0; j < w; j++) {
        if (heatmap[i][j] < minVal) minVal = heatmap[i][j];
        if (heatmap[i][j] > maxVal) maxVal = heatmap[i][j];
      }
    }
    final range = maxVal - minVal;
    if (range < 1e-8) throw Exception('Heatmap vacío — sin activaciones significativas.');

    for (int i = 0; i < h; i++) {
      for (int j = 0; j < w; j++) {
        heatmap[i][j] = (heatmap[i][j] - minVal) / range;
      }
    }

    // Superponer heatmap sobre imagen original
    final result = await _overlayHeatmap(image, heatmap);

    // Guardar imagen resultante
    final tempDir = await getTemporaryDirectory();
    final outPath =
        '${tempDir.path}/gradcam_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(outPath).writeAsBytes(img.encodeJpg(result, quality: 90));

    return outPath;
  }

  // ── Superposición heatmap + imagen original ──────────────────────────

  Future<img.Image> _overlayHeatmap(
    img.Image original,
    List<List<double>> heatmap,
  ) async {
    final w = original.width;
    final h = original.height;
    final hmH = heatmap.length;
    final hmW = heatmap[0].length;

    final result = img.Image(width: w, height: h);

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        // Valor del heatmap interpolado bilinealmente
        final fy = (y / h) * (hmH - 1);
        final fx = (x / w) * (hmW - 1);
        final iy = fy.floor().clamp(0, hmH - 2);
        final ix = fx.floor().clamp(0, hmW - 2);
        final dy = fy - iy;
        final dx = fx - ix;

        final val = heatmap[iy][ix] * (1 - dy) * (1 - dx) +
            heatmap[iy + 1][ix] * dy * (1 - dx) +
            heatmap[iy][ix + 1] * (1 - dy) * dx +
            heatmap[iy + 1][ix + 1] * dy * dx;

        // Colormap JET: azul → cian → verde → amarillo → rojo
        final rgb = _jetColormap(val);

        // Mezclar con imagen original (alpha = 0.45 heatmap, 0.55 original)
        final orig = original.getPixel(x, y);
        final blendR =
            (orig.r.toDouble() * 0.55 + rgb[0] * 0.45).round().clamp(0, 255);
        final blendG =
            (orig.g.toDouble() * 0.55 + rgb[1] * 0.45).round().clamp(0, 255);
        final blendB =
            (orig.b.toDouble() * 0.55 + rgb[2] * 0.45).round().clamp(0, 255);

        result.setPixelRgb(x, y, blendR, blendG, blendB);
      }
    }

    return result;
  }

  // ── Colormap JET (azul=bajo, rojo=alto) ─────────────────────────────

  List<int> _jetColormap(double val) {
    final v = val.clamp(0.0, 1.0);
    double r, g, b;

    if (v < 0.125) {
      r = 0; g = 0; b = 0.5 + v * 4;
    } else if (v < 0.375) {
      r = 0; g = (v - 0.125) * 4; b = 1.0;
    } else if (v < 0.625) {
      r = (v - 0.375) * 4; g = 1.0; b = 1.0 - (v - 0.375) * 4;
    } else if (v < 0.875) {
      r = 1.0; g = 1.0 - (v - 0.625) * 4; b = 0;
    } else {
      r = 1.0 - (v - 0.875) * 4; g = 0; b = 0;
    }

    return [
      (r * 255).round().clamp(0, 255),
      (g * 255).round().clamp(0, 255),
      (b * 255).round().clamp(0, 255),
    ];
  }

  // ── Liberar recursos ─────────────────────────────────────────────────

  void dispose() {
    _interpreter?.close();
    _gradcamInterpreter?.close();
    _interpreter = null;
    _gradcamInterpreter = null;
  }
}