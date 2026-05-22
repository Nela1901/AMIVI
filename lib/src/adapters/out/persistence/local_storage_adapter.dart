import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../../application/ports/output/local_storage_port.dart';
import '../../../domain/entities/road_incidence.dart';

class LocalStorageAdapter implements LocalStoragePort {
  Future<File> _getLocalFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/pending_inspections.json');
  }

  @override
  Future<void> saveOffline(RoadIncidence incidence, String imagePath, {String? direccion, String? observaciones}) async {
    try {
      // [HU-17 - Escenario 1]: Almacenamiento local exitoso.
      final file = await _getLocalFile();
      List<dynamic> reports = [];
      
      if (await file.exists()) {
        reports = json.decode(await file.readAsString());
      }

      reports.add({
        'id': incidence.id,
        'imagePath': imagePath,
        'clase': incidence.damageLevel.name,
        'confianza': incidence.confidence,
        'latitud': incidence.latitude,
        'longitud': incidence.longitude,
        'direccion': direccion,
        'observaciones': observaciones,
        'fechaHora': incidence.detectedAt.toIso8601String(),
        'isOffline': true,
      });

      await file.writeAsString(json.encode(reports));
    } catch (e) {
      // [HU-17 - Escenario 2]: Error de almacenamiento local (Falla de escritura).
      throw Exception('No fue posible almacenar la incidencia localmente: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getAllPendingReports() async {
    // [HU-18 - Escenario 1]: Recuperación de reportes locales para sincronización.
    final file = await _getLocalFile();
    if (!await file.exists()) return [];
    
    final content = await file.readAsString();
    return List<Map<String, dynamic>>.from(json.decode(content));
  }

  @override
  Future<void> deleteReport(String id) async {
    final file = await _getLocalFile();
    if (!await file.exists()) return;

    final reports = List<Map<String, dynamic>>.from(json.decode(await file.readAsString()));
    reports.removeWhere((r) => r['id'] == id);
    await file.writeAsString(json.encode(reports));
  }
}