import 'package:flutter/material.dart';

class ArchivosScreen extends StatelessWidget {
  const ArchivosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Archivos'),
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
                    Icon(Icons.folder_open, size: 48, color: Color(0xfff97316)),
                    SizedBox(height: 12),
                    Text(
                      'Gestión de archivos',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Sube y gestiona tus archivos',
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
                  const SnackBar(content: Text('Función de subida de archivos')),
                );
              },
              icon: const Icon(Icons.upload_file),
              label: const Text('Subir archivo'),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              'Archivos recientes',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildFileItem('documento.pdf', '2.5 MB'),
            _buildFileItem('imagen.jpg', '1.2 MB'),
            _buildFileItem('presentacion.pptx', '5.8 MB'),
          ],
        ),
      ),
    );
  }

  Widget _buildFileItem(String name, String size) {
    return Card(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.insert_drive_file, color: Color(0xfff97316)),
        title: Text(name),
        subtitle: Text(size),
        trailing: const Icon(Icons.more_vert),
      ),
    );
  }
}
