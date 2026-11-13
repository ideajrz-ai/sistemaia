import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'workspace_screen.dart';

class GeocercasScreen extends StatefulWidget {
  const GeocercasScreen({super.key, required this.userId});
  final String userId;
  @override
  State<GeocercasScreen> createState() => _GeocercasScreenState();
}

class _GeocercasScreenState extends State<GeocercasScreen> {
  List<Map<String, dynamic>> fences = [];
  LatLng? point;
  bool ready = false;
  String get storageKey => 'geocercas_${widget.userId}';
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonDecode(prefs.getString(storageKey) ?? '[]') as List;
      if (mounted) {
        setState(() {
          fences = data.map((e) => Map<String, dynamic>.from(e)).toList();
          ready = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => ready = true);
        notify(context, 'No se pudieron leer las geocercas: $e');
      }
    }
  }

  Future<void> save(List<Map<String, dynamic>> values) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(storageKey, jsonEncode(values))) {
        throw Exception('No se pudo guardar');
      }
      if (mounted) setState(() => fences = values);
    } catch (e) {
      if (mounted) notify(context, e);
    }
  }

  Future<void> create() async {
    if (point == null) {
      notify(context, 'Toca el mapa para elegir el centro.');
      return;
    }
    final center = point!;
    final name = TextEditingController(),
        radius = TextEditingController(text: '200');
    final form = GlobalKey<FormState>();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Nueva geocerca circular'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (v) =>
                    v!.trim().isEmpty ? 'Ingresa un nombre' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: radius,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Radio en metros'),
                validator: (v) {
                  final n = double.tryParse(v ?? '');
                  return n == null || !n.isFinite || n <= 0 || n > 100000
                      ? 'Usa un radio entre 1 y 100000 metros'
                      : null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(c, <String, dynamic>{
                  'id': DateTime.now().microsecondsSinceEpoch.toString(),
                  'nombre': name.text.trim(),
                  'lat': center.latitude,
                  'lng': center.longitude,
                  'radio': double.parse(radius.text),
                });
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    // Controllers are released after the dialog transition finishes.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    name.dispose();
    radius.dispose();
    if (result != null && mounted) await save([...fences, result]);
  }

  LatLng center(Map<String, dynamic> g) =>
      LatLng((g['lat'] as num).toDouble(), (g['lng'] as num).toDouble());
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Geocercas')),
    floatingActionButton: FloatingActionButton(
      onPressed: ready ? create : null,
      child: const Icon(Icons.add_location_alt),
    ),
    body: !ready
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Toca el mapa para seleccionar un punto. Las geocercas se guardan en este dispositivo para tu cuenta.',
                ),
              ),
              Expanded(
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: fences.isEmpty
                        ? const LatLng(31.6904, -106.4245)
                        : center(fences.first),
                    initialZoom: 13,
                    onTap: (_, p) => setState(() => point = p),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'mx.sistemaia.consultoria',
                    ),
                    CircleLayer(
                      circles: [
                        for (final g in fences)
                          CircleMarker(
                            point: center(g),
                            radius: (g['radio'] as num).toDouble(),
                            useRadiusInMeter: true,
                            color: Colors.orange.withValues(alpha: .2),
                            borderColor: Colors.orange,
                            borderStrokeWidth: 2,
                          ),
                      ],
                    ),
                    if (point != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: point!,
                            child: const Icon(
                              Icons.place,
                              color: Colors.red,
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                    RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution(
                          'OpenStreetMap contributors',
                          onTap: () => launchUrl(
                            Uri.parse(
                              'https://www.openstreetmap.org/copyright',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (point != null)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    'Punto: ${point!.latitude.toStringAsFixed(5)}, ${point!.longitude.toStringAsFixed(5)} · ${fences.where((g) => const Distance().as(LengthUnit.Meter, center(g), point!) <= (g['radio'] as num)).length} geocercas lo contienen',
                  ),
                ),
              SizedBox(
                height: 180,
                child: ListView(
                  children: [
                    if (fences.isEmpty)
                      const ListTile(
                        title: Text('No hay geocercas guardadas.'),
                      ),
                    for (final g in fences)
                      ListTile(
                        title: Text('${g['nombre']}'),
                        subtitle: Text('Radio: ${g['radio']} m'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            if (await confirm(context, '¿Eliminar geocerca?')) {
                              await save(
                                fences
                                    .where((f) => f['id'] != g['id'])
                                    .toList(),
                              );
                            }
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
  );
}
