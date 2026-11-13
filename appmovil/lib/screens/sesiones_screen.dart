import 'package:flutter/material.dart';

class SesionesScreen extends StatelessWidget {
  const SesionesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sesiones'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (context, index) {
          return Card(
            color: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Theme.of(context).dividerColor),
            ),
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: const Icon(Icons.event, color: Color(0xfff97316)),
              title: Text('Sesión ${index + 1}'),
              subtitle: Text('Fecha: ${DateTime.now().subtract(Duration(days: index)).toString().split(' ')[0]}'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Ver detalles de sesión ${index + 1}')),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
