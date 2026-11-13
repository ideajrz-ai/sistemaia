import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: const Color(0xfff97316),
              ),
              child: const Icon(
                Icons.business,
                color: Color(0xff0b0b0c),
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
            const Text('SistemaIA · Consultoría'),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            _buildMenuCard(
              context,
              'Inicio',
              Icons.home,
              '/menus',
            ),
            const SizedBox(height: 12),
            _buildMenuCard(
              context,
              'Encuesta',
              Icons.poll,
              '/encuesta',
            ),
            const SizedBox(height: 12),
            _buildMenuCard(
              context,
              'Sesiones',
              Icons.event,
              '/sesiones',
            ),
            const SizedBox(height: 12),
            _buildMenuCard(
              context,
              'Archivos',
              Icons.folder,
              '/archivos',
            ),
            const SizedBox(height: 12),
            _buildMenuCard(
              context,
              'Citas',
              Icons.calendar_today,
              '/citas',
            ),
            const SizedBox(height: 12),
            _buildMenuCard(
              context,
              'QR',
              Icons.qr_code_scanner,
              '/qr',
            ),
            const SizedBox(height: 12),
            _buildMenuCard(
              context,
              'Geocercas',
              Icons.location_on,
              '/geocercas',
            ),
            const SizedBox(height: 12),
            _buildMenuCard(
              context,
              'Mi panel',
              Icons.dashboard,
              '/dashboard',
            ),
            const SizedBox(height: 12),
            _buildMenuCard(
              context,
              'Admin',
              Icons.admin_panel_settings,
              '/menus',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context,
    String title,
    IconData icon,
    String route,
  ) {
    return Card(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).dividerColor,
        ),
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xfff97316)),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => context.push(route),
      ),
    );
  }
}
