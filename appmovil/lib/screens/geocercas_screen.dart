import 'package:flutter/material.dart';

class GeocercasScreen extends StatelessWidget {
  const GeocercasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Geocercas'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Theme.of(context).dividerColor),
              ),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(Icons.location_on, size: 48, color: Color(0xfff97316)),
                    SizedBox(height: 12),
                    Text(
                      'Geocercas',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Define zonas geográficas para el sistema',
                      style: TextStyle(color: Color(0xff9b9b9b)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Crear nueva geocerca')),
                );
              },
              icon: const Icon(Icons.add_location),
              label: const Text('Crear geocerca'),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              'Geocercas activas',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildGeocercaItem('Oficina Central', 'Activa'),
            _buildGeocercaItem('Zona Industrial', 'Activa'),
            _buildGeocercaItem('Sucursal Norte', 'Inactiva'),
          ],
        ),
      ),
    );
  }

  Widget _buildGeocercaItem(String name, String status) {
    return Card(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.place, color: Color(0xfff97316)),
        title: Text(name),
        subtitle: Text(status),
        trailing: Chip(
          label: Text(
            status,
            style: const TextStyle(fontSize: 12),
          ),
          backgroundColor: status == 'Activa' 
              ? const Color(0xff4ade80) 
              : const Color(0xfff87171),
        ),
      ),
    );
  }
}
