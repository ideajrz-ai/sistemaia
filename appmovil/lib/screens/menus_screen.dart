import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MenusScreen extends StatelessWidget {
  const MenusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildMenuCard(
            context,
            'Encuesta',
            'Participa en encuestas de satisfacción',
            Icons.poll,
            '/encuesta',
          ),
          const SizedBox(height: 12),
          _buildMenuCard(
            context,
            'Sesiones',
            'Gestiona tus sesiones de consultoría',
            Icons.event,
            '/sesiones',
          ),
          const SizedBox(height: 12),
          _buildMenuCard(
            context,
            'Archivos',
            'Sube y gestiona tus archivos',
            Icons.folder,
            '/archivos',
          ),
          const SizedBox(height: 12),
          _buildMenuCard(
            context,
            'Citas',
            'Programa y gestiona tus citas',
            Icons.calendar_today,
            '/citas',
          ),
          const SizedBox(height: 12),
          _buildMenuCard(
            context,
            'QR',
            'Escanea códigos QR',
            Icons.qr_code_scanner,
            '/qr',
          ),
          const SizedBox(height: 12),
          _buildMenuCard(
            context,
            'Geocercas',
            'Define zonas geográficas',
            Icons.location_on,
            '/geocercas',
          ),
          const SizedBox(height: 12),
          _buildMenuCard(
            context,
            'Mi panel',
            'Ver tu panel de control',
            Icons.dashboard,
            '/dashboard',
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    String route,
  ) {
    return Card(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xfff97316)),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          description,
          style: const TextStyle(color: Color(0xff9b9b9b)),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => context.push(route),
      ),
    );
  }
}
