import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:amivi/src/adapters/in/controllers/classification_controller.dart'; // Import controller
import 'package:amivi/src/domain/entities/road_incidence.dart'; // Import RoadIncidence
import 'package:amivi/src/domain/services/road_safety_service.dart'; // Import para lógica de Hotspots
import 'package:amivi/src/domain/valueobjects/damage_level.dart'; // Import DamageLevel
import 'package:amivi/src/adapters/in/views/inspection_detail_screen.dart'; // Import detalle

class MapScreen extends StatefulWidget {
  final ClassificationController controller; // Accept controller
  const MapScreen({super.key, required this.controller}); // Require controller

  @override
  State<MapScreen> createState() => _MapScreenState();
}
class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Circle> _circles = {}; // [HU-IA-03]: Para visualización de Hotspots (Zonas Críticas)
  LatLng _currentMapCenter = const LatLng(-12.0484223, -75.243839); // Default to Huancayo

  @override
  void initState() {
    super.initState();
    _initializeMap();
    // Listen to controller for filter changes and location updates
    widget.controller.addListener(_onControllerChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChange);
    super.dispose();
  }

  void _onControllerChange() {
    // If user location changes, update map center
    if (widget.controller.userLocation != null && _mapController != null) {
      final newLat = widget.controller.userLocation!.latitude;
      final newLng = widget.controller.userLocation!.longitude;
      if (_currentMapCenter.latitude != newLat || _currentMapCenter.longitude != newLng) {
        _currentMapCenter = LatLng(newLat, newLng); // Update _currentMapCenter
        _mapController?.animateCamera(CameraUpdate.newLatLng(_currentMapCenter));
      }
    }
    // Rebuild the map to apply filters (StreamBuilder will handle this)
    setState(() {});
  }

  Future<void> _initializeMap() async {
    // [HU-20]: Consulta de incidencias cercanas (inicialización)
    await widget.controller.fetchAndSetCurrentLocation();
    if (widget.controller.userLocation != null) {
      setState(() {
        _currentMapCenter = LatLng(widget.controller.userLocation!.latitude, widget.controller.userLocation!.longitude);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de Incidencias', 
            style: TextStyle(color: Color(0xFF185FA5), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF185FA5)),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(context),
            tooltip: 'Filtrar incidencias',
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () async {
              await widget.controller.fetchAndSetCurrentLocation();
              if (widget.controller.userLocation != null) {
                _mapController?.animateCamera(CameraUpdate.newLatLng(
                  LatLng(widget.controller.userLocation!.latitude, widget.controller.userLocation!.longitude),
                ));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(widget.controller.warningMessage ?? 'No se pudo obtener tu ubicación.')),
                );
              }
            },
            tooltip: 'Centrar en mi ubicación',
          ),
        ],
      ),
      body: Stack(
        children: [
          StreamBuilder<List<RoadIncidence>>( // Listen to filtered stream
            stream: widget.controller.getFilteredInspectionsStream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          'No fue posible cargar el mapa correctamente: ${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                        TextButton(
                          onPressed: () => setState(() {}),
                          child: const Text('Reintentar'),
                        )
                      ],
                    ),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final incidents = snapshot.data ?? [];
              _updateMarkers(incidents); // Update markers with filtered incidents
              _updateHotspots(incidents); // [HU-IA-03 - Escenario 1]: Agrupación y Hotspots (PoC)

              if (incidents.isEmpty && (widget.controller.filterLevels.isNotEmpty || widget.controller.filterDateRange != null || widget.controller.maxDistanceKm > 0)) {
                // [HU-21 - Escenario 2]: No se encontraron resultados con los filtros aplicados.
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          'No se encontraron incidencias con los filtros aplicados.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                        TextButton(
                          onPressed: () => widget.controller.resetFilters(),
                          child: const Text('Restablecer filtros'),
                        )
                      ],
                    ),
                  ),
                );
              }

              return GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _currentMapCenter,
                  zoom: 15,
                ),
                onMapCreated: (controller) => _mapController = controller,
                markers: _markers,
                circles: _circles, // [HU-IA-03]: Capa de visualización de zonas de riesgo
                myLocationEnabled: true,
                myLocationButtonEnabled: false, // Custom button in AppBar
                mapType: MapType.normal,
              );
            },
          ),
          if (widget.controller.warningMessage != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.orange.shade100,
                padding: const EdgeInsets.all(8),
                child: Text(
                  widget.controller.warningMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.orange, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _updateMarkers(List<RoadIncidence> incidents) {
    _markers.clear();
    for (var incidence in incidents) {
      if (incidence.latitude != null && incidence.longitude != null) {
        _markers.add(Marker(
          markerId: MarkerId(incidence.id),
          position: LatLng(incidence.latitude!, incidence.longitude!),
          infoWindow: InfoWindow(
            title: 'Daño: ${incidence.damageLevel.label}',
            snippet: 'Toca para ver detalle',
            onTap: () => _navigateToDetail(incidence),
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(_getMarkerHueForDamageLevel(incidence.damageLevel)),
        ));
      }
    }
    // Add user's current location marker if available
    if (widget.controller.userLocation != null) {
      _markers.add(Marker(
        markerId: const MarkerId('user_location'),
        position: LatLng(widget.controller.userLocation!.latitude, widget.controller.userLocation!.longitude),
        infoWindow: InfoWindow(title: 'Mi Ubicación', snippet: widget.controller.userAddress ?? 'Ubicación actual'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ));
    }
  }

  void _navigateToDetail(RoadIncidence incidence) {
    // [HU-15]: Navegación al detalle desde el mapa
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InspectionDetailScreen(
          docId: incidence.id,
          data: {
            'clase': incidence.damageLevel.name,
            'confianza': incidence.confidence,
            'fechaHora': Timestamp.fromDate(incidence.detectedAt),
            'direccion': incidence.address,
            'latitud': incidence.latitude,
            'longitud': incidence.longitude,
            'observaciones': incidence.observations,
            'imagenUrl': incidence.imagePath, // Asumimos que es la URL si viene de Firestore
          },
        ),
      ),
    );
  }

  // [HU-IA-03 - Escenario 1]: Prueba de concepto para consolidación de incidencias
  void _updateHotspots(List<RoadIncidence> incidents) {
    _circles.clear();
    final safetyService = RoadSafetyService();

    // Filtramos solo incidencias que representan riesgos críticos o altos
    final criticalIncidents = incidents.where((inc) => 
      safetyService.shouldTriggerEmergencyAlert(inc.damageLevel, inc.confidence)
    ).toList();

    // Algoritmo básico de agrupación (Clustering): 
    // Si detectamos densidad de fallas críticas en un radio pequeño, marcamos un Hotspot.
    for (var i = 0; i < criticalIncidents.length; i++) {
      final current = criticalIncidents[i];
      if (current.latitude == null || current.longitude == null) continue;

      int densityCount = 0;
      for (var j = 0; j < criticalIncidents.length; j++) {
        final other = criticalIncidents[j];
        if (other.latitude == null || other.longitude == null) continue;

        final distance = widget.controller.calculateDistance(
          current.latitude!, current.longitude!, 
          other.latitude!, other.longitude!
        );

        if (distance < 0.2) densityCount++; // Radio de 200 metros
      }

      // [UC-IA-13]: Si hay más de 2 incidencias críticas cercanas, consolidamos como Zona Crítica
      if (densityCount >= 2) {
        _circles.add(Circle(
          circleId: CircleId('hotspot_${current.id}'),
          center: LatLng(current.latitude!, current.longitude!),
          radius: 120, // Área de influencia visual del hotspot
          fillColor: Colors.red.withOpacity(0.35),
          strokeColor: Colors.red.withOpacity(0.6),
          strokeWidth: 2,
        ));
      }
    }
  }

  double _getMarkerHueForDamageLevel(DamageLevel level) {
    switch (level) {
      case DamageLevel.normal:
        return BitmapDescriptor.hueGreen;
      case DamageLevel.leve:
        return BitmapDescriptor.hueOrange;
      case DamageLevel.danado:
        return BitmapDescriptor.hueRed;
    }
  }

  void _showFilterDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return FilterDialog(controller: widget.controller);
      },
    );
  }
}

// New Widget for Filter Dialog
class FilterDialog extends StatelessWidget {
  final ClassificationController controller;

  const FilterDialog({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Filtrar Incidencias', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 16),

              // Filter by Damage Level
              const Text('Tipo de Daño:', style: TextStyle(fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 8.0,
                children: DamageLevel.values.map((level) {
                  return FilterChip(
                    label: Text(level.label),
                    selected: controller.filterLevels.contains(level),
                    onSelected: (selected) {
                      controller.toggleFilterLevel(level);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Filter by Date Range
              const Text('Rango de Fechas:', style: TextStyle(fontWeight: FontWeight.bold)),
              ListTile(
                title: Text(
                  controller.filterDateRange == null
                      ? 'Seleccionar rango'
                      : '${_formatDate(controller.filterDateRange!.start)} - ${_formatDate(controller.filterDateRange!.end)}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final DateTimeRange? picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    initialDateRange: controller.filterDateRange,
                  );
                  if (picked != null && picked != controller.filterDateRange) {
                    controller.setDateRange(picked);
                  }
                },
              ),
              const SizedBox(height: 16),

              // Filter by Proximity
              const Text('Distancia Máxima (Km):', style: TextStyle(fontWeight: FontWeight.bold)),
              Slider(
                value: controller.maxDistanceKm,
                min: 0,
                max: 50,
                divisions: 50,
                label: controller.maxDistanceKm.toStringAsFixed(0),
                onChanged: (value) {
                  controller.setMaxDistance(value);
                },
              ),
              Text('Incidencias a menos de ${controller.maxDistanceKm.toStringAsFixed(0)} Km de mi ubicación.',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 24),

              // Reset Filters Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    controller.resetFilters();
                    Navigator.pop(context); // Close dialog after resetting
                  },
                  child: const Text('Restablecer Filtros'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF185FA5),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Aplicar Filtros'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}