import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart'; // Requerido para debugPrint
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../domain/entities/road_incidence.dart';
import '../../../application/ports/output/save_inspection_port.dart';

class FirestoreAdapter implements SaveInspectionPort {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static String get _cloudName => dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
  static String get _uploadPreset => dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '';

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
    double? latitud,
    double? longitud,
    String? direccion,
    String? observaciones,
  }) async {
    // [HU-18]: Verificamos si el archivo de imagen aún existe en el dispositivo
    if (!await File(imagePath).exists()) {
      throw Exception('El archivo de imagen original ya no existe. El reporte está huérfano.');
    }

    // Subir imagen a Cloudinary
    final imageUrl = await _uploadToCloudinary(imagePath);

    // Guardar en Firestore
    final docRef = await _firestore.collection('inspecciones').add({
      'uid': FirebaseAuth.instance.currentUser?.uid, // Vinculación obligatoria para las reglas
      'imagenUrl': imageUrl,
      'clase': incidence.damageLevel.name,
      'confianza': incidence.confidence,
      'latitud': latitud, // HU-06: Coordenada asociada al reporte de la incidencia vial
      'longitud': longitud, // HU-06: Coordenada asociada al reporte de la incidencia vial
      'direccion': direccion, // HU-07: Dirección aproximada obtenida
      'observaciones': observaciones, // HU-07: Información complementaria
      'fechaHora': FieldValue.serverTimestamp(),
      'requiereIntervencion': incidence.requiresIntervention,
      'requiereMonitoreo': incidence.requiresMonitoring,
    });

    // [HU-18]: Borrar el archivo local SOLO cuando el guardado en Firestore fue exitoso.
    // Si Firestore falla, el archivo debe permanecer para reintentar la subida después.
    try {
      await File(imagePath).delete();
    } catch (e) {
      debugPrint('Error al limpiar archivo temporal: $e');
    }

    return docRef.id;
  }
}