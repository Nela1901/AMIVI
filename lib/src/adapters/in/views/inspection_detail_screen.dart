import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class InspectionDetailScreen extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;

  const InspectionDetailScreen({super.key, required this.data, required this.docId});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('No se pudo recuperar la información de la incidencia.', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    final date = (data['fechaHora'] as Timestamp?)?.toDate() ?? DateTime.now();
    final lat = data['latitud'];
    final lng = data['longitud'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Inspección', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(data['imagenUrl'] ?? '', 
                  height: 250, width: double.infinity, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(height: 200, color: Colors.grey[300], child: const Icon(Icons.broken_image))),
            ),
            const SizedBox(height: 20),
            _buildInfoRow('Tipo de Daño', data['clase']?.toString().toUpperCase() ?? 'N/A', Icons.warning_amber_rounded),
            _buildInfoRow('Confianza Estimada', '${((data['confianza'] ?? 0) * 100).toStringAsFixed(1)}%', Icons.verified_outlined),
            _buildInfoRow('Fecha y Hora', '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute}', Icons.calendar_today),
            _buildInfoRow('Dirección', data['direccion'] ?? 'No registrada', Icons.location_on),
            if (lat != null && lng != null)
              _buildInfoRow('Coordenadas', '$lat, $lng', Icons.gps_fixed),
            const Divider(height: 32),
            const Text('Observaciones', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text(data['observaciones'] ?? 'Sin observaciones adicionales.', style: const TextStyle(fontSize: 14, color: Colors.black87)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF185FA5)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
       ),
    );
  }
}