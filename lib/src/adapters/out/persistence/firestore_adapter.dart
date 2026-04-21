import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../domain/entities/road_incidence.dart';
import '../../../application/ports/output/save_inspection_port.dart';

class FirestoreAdapter implements SaveInspectionPort {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _cloudName = 'djeruiyop';
  static const String _uploadPreset = 'amivi_preset';

  Future<String> _uploadToCloudinary(String imagePath) async {
    final url = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/image/upload');

    final request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = _uploadPreset
      ..fields['folder'] = 'inspecciones'
      ..files.add(await http.MultipartFile.fromPath('file', imagePath));

    final response = await request.send();
    final responseData = await response.stream.toBytes();
    final jsonResponse = json.decode(String.fromCharCodes(responseData));

    if (response.statusCode == 200) {
      return jsonResponse['secure_url'];
    } else {
      throw Exception('Error al subir imagen: ${jsonResponse['error']['message']}');
    }
  }

  @override
  Future<String> saveInspection({
    required RoadIncidence incidence,
    required String imagePath,
    required double latitud,
    required double longitud,
  }) async {
    // Subir imagen a Cloudinary
    final imageUrl = await _uploadToCloudinary(imagePath);

    // Borrar copia temporal después de subir
    try { await File(imagePath).delete(); } catch (_) {}

    // Guardar en Firestore
    final docRef = await _firestore.collection('inspecciones').add({
      'imagenUrl': imageUrl,
      'clase': incidence.damageLevel.name,
      'confianza': incidence.confidence,
      'latitud': latitud,
      'longitud': longitud,
      'fechaHora': FieldValue.serverTimestamp(),
      'requiereIntervencion': incidence.requiresIntervention,
      'requiereMonitoreo': incidence.requiresMonitoring,
    });

    return docRef.id;
  }
}