import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'src/adapters/out/ai/ai_detector_adapter.dart';
import 'src/adapters/out/persistence/firestore_adapter.dart';
import 'src/adapters/in/controllers/classification_controller.dart';
import 'src/application/usecases/classify_road_image_usecase.dart';
import 'src/application/usecases/save_inspection_usecase.dart';
import 'src/domain/entities/road_incidence.dart';
import 'src/domain/valueobjects/damage_level.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(AMIVIApp());
}

class AMIVIApp extends StatelessWidget {
  const AMIVIApp({super.key});

  @override
  Widget build(BuildContext context) {
    final aiAdapter = AiDetectorAdapter();
    final firestoreAdapter = FirestoreAdapter();
    final classifyUsecase = ClassifyRoadImageUsecase(aiAdapter);
    final saveUsecase = SaveInspectionUsecase(firestoreAdapter);
    final controller = ClassificationController(classifyUsecase, saveUsecase);

    return MaterialApp(
      title: 'AMIVI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF185FA5),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: ClassificationScreen(controller: controller),
    );
  }
}

class ClassificationScreen extends StatefulWidget {
  final ClassificationController controller;

  const ClassificationScreen({super.key, required this.controller});

  @override
  State<ClassificationScreen> createState() => _ClassificationScreenState();
}

class _ClassificationScreenState extends State<ClassificationScreen> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    final XFile? file = await _picker.pickImage(source: source);
    if (file != null) {
      widget.controller.setImagePath(file.path);
    }
  }

  Color _getColorForLevel(DamageLevel level) {
    switch (level) {
      case DamageLevel.normal:
        return const Color(0xFF3B6D11);
      case DamageLevel.leve:
        return const Color(0xFF854F0B);
      case DamageLevel.danado:
        return const Color(0xFFA32D2D);
    }
  }

  Color _getBgColorForLevel(DamageLevel level) {
    switch (level) {
      case DamageLevel.normal:
        return const Color(0xFFEAF3DE);
      case DamageLevel.leve:
        return const Color(0xFFFAEEDA);
      case DamageLevel.danado:
        return const Color(0xFFFCEBEB);
    }
  }

  String _getIconForLevel(DamageLevel level) {
    switch (level) {
      case DamageLevel.normal:
        return '✓';
      case DamageLevel.leve:
        return '⚠';
      case DamageLevel.danado:
        return '✕';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            title: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF185FA5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.map_outlined,
                      color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AMIVI',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF185FA5))),
                    Text('Inspección Vial Inteligente',
                        style:
                            TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Zona de imagen
                Container(
                  height: 220,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: controller.selectedImagePath != null
                          ? const Color(0xFF185FA5)
                          : const Color(0xFFDDE3ED),
                      width:
                          controller.selectedImagePath != null ? 2 : 1,
                    ),
                  ),
                  child: controller.selectedImagePath != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Image.file(
                            File(controller.selectedImagePath!),
                            fit: BoxFit.cover,
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined,
                                size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text(
                                'Selecciona o captura una imagen',
                                style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 14)),
                            const SizedBox(height: 4),
                            Text('JPG, PNG recomendado',
                                style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 11)),
                          ],
                        ),
                ),
                const SizedBox(height: 12),

                // Botones selección
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickImage(ImageSource.gallery),
                        icon: const Icon(
                            Icons.photo_library_outlined,
                            size: 18),
                        label: const Text('Galería'),
                        style: OutlinedButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(
                              color: Color(0xFF185FA5)),
                          foregroundColor: const Color(0xFF185FA5),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickImage(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_outlined,
                            size: 18),
                        label: const Text('Cámara'),
                        style: OutlinedButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(
                              color: Color(0xFF185FA5)),
                          foregroundColor: const Color(0xFF185FA5),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Botón clasificar
                ElevatedButton(
                  onPressed: controller.selectedImagePath != null &&
                          controller.state !=
                              ClassificationState.loading
                      ? () => widget.controller.classify()
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF185FA5),
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: controller.state ==
                          ClassificationState.loading
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2),
                            ),
                            SizedBox(width: 10),
                            Text('Analizando...'),
                          ],
                        )
                      : const Text('Clasificar imagen',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 20),

                // Resultado
                if (controller.state == ClassificationState.success &&
                    controller.result != null)
                  _buildResult(controller.result!, controller),

                // Error clasificación
                if (controller.state == ClassificationState.error)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFCEBEB),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      controller.errorMessage ?? 'Error desconocido',
                      style:
                          const TextStyle(color: Color(0xFFA32D2D)),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildResult(
      RoadIncidence result, ClassificationController controller) {
    final color = _getColorForLevel(result.damageLevel);
    final bgColor = _getBgColorForLevel(result.damageLevel);
    final icon = _getIconForLevel(result.damageLevel);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Card resultado
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(icon,
                  style: TextStyle(fontSize: 36, color: color)),
              const SizedBox(height: 8),
              Text(result.damageLevel.label,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: color)),
              const SizedBox(height: 4),
              Text(result.damageLevel.description,
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(fontSize: 13, color: color)),
              const SizedBox(height: 12),
              Text(
                'Confianza: ${(result.confidence * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: color),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Probabilidades
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFDDE3ED)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Probabilidades por clase',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey)),
              const SizedBox(height: 12),
              ...result.probabilities.entries.map((e) {
                final pct = e.value * 100;
                final barColor = _getColorForLevel(e.key);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Text(e.key.label,
                              style:
                                  const TextStyle(fontSize: 13)),
                          Text('${pct.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: LinearProgressIndicator(
                          value: e.value,
                          backgroundColor: Colors.grey[200],
                          valueColor:
                              AlwaysStoppedAnimation(barColor),
                          minHeight: 7,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Advertencia galería
        if (controller.selectedImagePath != null &&
            !controller.selectedImagePath!.contains('camera'))
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAEEDA),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline,
                    color: Color(0xFF854F0B), size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'La ubicación corresponde a tu posición actual, no a la de la foto.',
                    style: TextStyle(
                        fontSize: 11, color: Color(0xFF854F0B)),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),

        // Botón registrar
        if (controller.saveState != SaveState.saved)
          ElevatedButton.icon(
            onPressed: controller.saveState == SaveState.saving
                ? null
                : () => controller.saveInspection(),
            icon: controller.saveState == SaveState.saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined, size: 18),
            label: Text(
              controller.saveState == SaveState.saving
                  ? 'Registrando...'
                  : 'Registrar inspección',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F6E56),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),

        // Confirmación guardado
        if (controller.saveState == SaveState.saved)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF3DE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle_outline,
                    color: Color(0xFF3B6D11)),
                SizedBox(width: 10),
                Text('Inspección registrada correctamente',
                    style: TextStyle(
                        color: Color(0xFF3B6D11),
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),

        // Error guardado
        if (controller.saveState == SaveState.error)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFCEBEB),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              controller.errorMessage ?? 'Error al registrar',
              style: const TextStyle(color: Color(0xFFA32D2D)),
            ),
          ),


        const SizedBox(height: 12),

        // Botón nueva inspección
        OutlinedButton(
          onPressed: () => controller.reset(),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            side: const BorderSide(color: Color(0xFF185FA5)),
            foregroundColor: const Color(0xFF185FA5),
          ),
          child: const Text('Nueva inspección'),
        ),
      ],
    );
  }
}