import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api.dart';
import 'ocr_screen.dart';
import 'geocercas_screen.dart';
import 'survey_screen.dart';

void notify(BuildContext context, Object message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message.toString().replaceFirst('Exception: ', ''))),
  );
}

String dateLabel(dynamic value) {
  final date = DateTime.tryParse('$value')?.toLocal();
  if (date == null) return value?.toString() ?? '';
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

Future<bool> confirm(BuildContext context, String title) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: const Text('Esta acción eliminará el registro.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    ) ??
    false;

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({super.key, required this.api});
  final Api api;
  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  late Future<Map<String, dynamic>> profile;
  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    profile = widget.api.call('me');
  }

  Future<void> open(Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => screen),
    );
    if (mounted) setState(reload);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('SistemaIA · Consultoría'),
      actions: [
        IconButton(
          tooltip: 'Actualizar',
          icon: const Icon(Icons.refresh),
          onPressed: () => setState(reload),
        ),
        IconButton(
          tooltip: 'Cerrar sesión',
          icon: const Icon(Icons.logout),
          onPressed: () async {
            try {
              await widget.api.auth.auth.signOut();
            } catch (e) {
              if (context.mounted) notify(context, e);
            }
          },
        ),
      ],
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: profile,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${snapshot.error}'),
                  FilledButton(
                    onPressed: () => setState(reload),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          );
        }
        final p = snapshot.data?['perfil'] as Map<String, dynamic>?;
        if (p == null) {
          return const Center(
            child: Text('No se encontró tu perfil. Contacta al administrador.'),
          );
        }
        final admin = p['rol'] == 'admin';
        final visible = List<String>.from(p['modulos_visibles'] ?? []);
        final modules = <(String, String, IconData, Widget)>[
          (
            'panel',
            'Mi perfil',
            Icons.person,
            ProfileScreen(api: widget.api, profile: p),
          ),
          (
            'encuesta',
            'Encuesta y diagnóstico',
            Icons.poll,
            SurveyScreen(api: widget.api),
          ),
          (
            'sesiones',
            'Sesiones',
            Icons.event_note,
            ResourceScreen(api: widget.api, resource: 'sesiones'),
          ),
          (
            'archivos',
            'Archivos',
            Icons.folder,
            ResourceScreen(api: widget.api, resource: 'archivos'),
          ),
          (
            'citas',
            'Citas',
            Icons.calendar_month,
            ResourceScreen(api: widget.api, resource: 'citas'),
          ),
          (
            'qr',
            'Mi QR de acceso',
            Icons.qr_code,
            ResourceScreen(api: widget.api, resource: 'qr'),
          ),
          (
            'geocercas',
            'Geocercas del dispositivo',
            Icons.map,
            GeocercasScreen(userId: widget.api.auth.auth.currentUser!.id),
          ),
        ];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Hola, ${p['nombre'] ?? 'bienvenido'}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '${p['email'] ?? ''} · ${admin ? 'Administrador' : 'Cliente'}',
            ),
            const SizedBox(height: 20),
            for (final m in modules)
              if (admin || visible.contains(m.$1))
                Card(
                  child: ListTile(
                    leading: Icon(m.$3),
                    title: Text(m.$2),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => open(m.$4),
                  ),
                ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.document_scanner),
                title: const Text('Leer texto de una foto'),
                subtitle: const Text('Cámara o galería · OCR'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => open(const OCRScreen()),
              ),
            ),
            if (admin)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.admin_panel_settings),
                  title: const Text('Clientes y permisos'),
                  onTap: () => open(ClientsScreen(api: widget.api)),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.api, required this.profile});
  final Api api;
  final Map<String, dynamic> profile;
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final fields = {
    for (final key in ['nombre', 'telefono', 'direccion', 'necesidad'])
      key: TextEditingController(text: '${widget.profile[key] ?? ''}'),
  };
  bool busy = false;
  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mi perfil')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('${widget.profile['email']}'),
        const SizedBox(height: 16),
        for (final field in fields.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: TextField(
              controller: field.value,
              decoration: InputDecoration(
                labelText: {
                  'nombre': 'Nombre',
                  'telefono': 'Teléfono',
                  'direccion': 'Dirección',
                  'necesidad': 'Necesidad de consultoría',
                }[field.key],
              ),
            ),
          ),
        FilledButton(
          onPressed: busy
              ? null
              : () async {
                  if (fields['nombre']!.text.trim().isEmpty) {
                    notify(context, 'Ingresa tu nombre.');
                    return;
                  }
                  setState(() => busy = true);
                  try {
                    await widget.api.call(
                      'me',
                      method: 'PATCH',
                      body: fields.map(
                        (key, value) => MapEntry(key, value.text.trim()),
                      ),
                    );
                    if (context.mounted) notify(context, 'Perfil guardado');
                  } catch (e) {
                    if (context.mounted) notify(context, e);
                  } finally {
                    if (mounted) setState(() => busy = false);
                  }
                },
          child: Text(busy ? 'Guardando…' : 'Guardar cambios'),
        ),
        TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => PasswordScreen(api: widget.api),
            ),
          ),
          child: const Text('Cambiar contraseña'),
        ),
      ],
    ),
  );
}

class ResourceScreen extends StatefulWidget {
  const ResourceScreen({super.key, required this.api, required this.resource});
  final Api api;
  final String resource;
  @override
  State<ResourceScreen> createState() => _ResourceScreenState();
}

class _ResourceScreenState extends State<ResourceScreen> {
  List<dynamic> items = [];
  String? error;
  bool loading = true, busy = false;
  Map<String, dynamic>? qr;
  String get resource => widget.resource;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await widget.api.call(
        resource == 'qr' ? 'qr/mios?mios=1' : '$resource?mios=1',
      );
      if (mounted) {
        setState(
          () => items = List<dynamic>.from(
            data[resource == 'archivos'
                    ? 'archivos'
                    : resource == 'qr'
                    ? 'qr'
                    : 'items'] ??
                [],
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> action(Future<void> Function() work) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await work();
      if (mounted) await load();
    } catch (e) {
      if (mounted) notify(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> upload() async {
    final selected = await FilePicker.pickFiles();
    if (selected.isEmpty) return;
    final file = selected.single;
    if (file.size > 20 * 1024 * 1024) {
      throw Exception('El tamaño máximo es 20 MB.');
    }
    final bytes =
        file.bytes ??
        (file.path == null ? null : await File(file.path!).readAsBytes());
    if (bytes == null) throw Exception('No se pudo leer el archivo.');
    final storage = widget.api.auth.storage.from('archivos-consultoria');
    final mime = lookupMimeType(file.name) ?? 'application/octet-stream';
    final path =
        '${widget.api.auth.auth.currentUser!.id}/${DateTime.now().microsecondsSinceEpoch}-${file.name.replaceAll(RegExp(r"[^a-zA-Z0-9._-]"), "_")}';
    await storage.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: mime),
    );
    try {
      await widget.api.call(
        'archivos',
        method: 'POST',
        body: {
          'nombre': file.name,
          'tipo_mime': mime,
          'tamano_bytes': bytes.length,
          'ruta_storage': path,
        },
      );
    } catch (_) {
      await storage.remove([path]);
      rethrow;
    }
    if (mounted) notify(context, 'Archivo subido');
  }

  Future<void> create() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => ScheduleEditor(resource: resource)),
    );
    if (result != null) {
      await action(() async {
        await widget.api.call(resource, method: 'POST', body: result);
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        {
          'sesiones': 'Sesiones',
          'citas': 'Citas',
          'archivos': 'Archivos',
          'qr': 'QR de acceso',
        }[resource]!,
      ),
      actions: [
        IconButton(
          onPressed: busy ? null : load,
          icon: const Icon(Icons.refresh),
          tooltip: 'Actualizar',
        ),
      ],
    ),
    floatingActionButton: busy
        ? const FloatingActionButton(
            onPressed: null,
            child: CircularProgressIndicator(),
          )
        : FloatingActionButton(
            tooltip: resource == 'qr'
                ? 'Generar QR de acceso'
                : resource == 'archivos'
                ? 'Subir archivo'
                : 'Crear registro',
            onPressed: () {
              if (resource == 'archivos') {
                action(upload);
              } else if (resource == 'qr') {
                action(() async {
                  final value = await widget.api.call(
                    'qr',
                    method: 'POST',
                    // El servidor determina la fecha de validez del acceso.
                    body: {},
                  );
                  if (mounted) setState(() => qr = value);
                });
              } else {
                create();
              }
            },
            child: Icon(
              resource == 'qr'
                  ? Icons.qr_code
                  : resource == 'archivos'
                  ? Icons.upload_file
                  : Icons.add,
            ),
          ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(error!),
                  FilledButton(
                    onPressed: load,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          )
        : RefreshIndicator(
            onRefresh: load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (resource == 'qr')
                  const Text(
                    'Genera tu QR para mostrarlo en recepción. Es válido un solo uso en la fecha indicada.',
                  ),
                if (qr != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Image.memory(
                            base64Decode((qr!['qr'] as String).split(',').last),
                            width: 280,
                          ),
                          Text('Válido: ${qr!['fecha_valida']}'),
                          Text('${qr!['aviso']}'),
                        ],
                      ),
                    ),
                  ),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Todavía no hay registros. Usa el botón + para empezar.',
                    ),
                  ),
                for (final item in items)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item['titulo'] ?? item['nombre'] ?? item['fecha_valida'] ?? ''}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (resource == 'sesiones') ...[
                            Text(
                              '${item['fecha']} · ${item['hora_inicio'] ?? 'Sin hora'} · ${item['duracion_min']} min',
                            ),
                            Text('Estado: ${item['estado']}'),
                            if (item['descripcion'] != null)
                              Text('${item['descripcion']}'),
                          ],
                          if (resource == 'citas') ...[
                            Text(dateLabel(item['fecha_inicio'])),
                            if (item['fecha_fin'] != null)
                              Text('Hasta ${dateLabel(item['fecha_fin'])}'),
                            Text(
                              'Recordatorio: ${item['recordatorio_min']} minutos antes',
                            ),
                          ],
                          if (item['notas'] != null) Text('${item['notas']}'),
                          if (resource == 'qr')
                            Text(
                              item['usado'] == true
                                  ? 'Utilizado'
                                  : 'Sin utilizar · expira ${dateLabel(item['expira_at'])}',
                            ),
                          if (resource == 'archivos')
                            Text(
                              '${((item['tamano_bytes'] ?? 0) / 1024).toStringAsFixed(1)} KB',
                            ),
                          Wrap(
                            spacing: 8,
                            children: [
                              if (resource == 'sesiones' &&
                                  item['estado'] == 'programada')
                                for (final state in ['realizada', 'cancelada'])
                                  TextButton(
                                    onPressed: busy
                                        ? null
                                        : () => action(() async {
                                            await widget.api.call(
                                              '$resource/${item['id']}',
                                              method: 'PATCH',
                                              body: {'estado': state},
                                            );
                                          }),
                                    child: Text(
                                      state == 'realizada'
                                          ? 'Marcar realizada'
                                          : 'Cancelar sesión',
                                    ),
                                  ),
                              if (resource == 'archivos')
                                TextButton(
                                  onPressed: busy
                                      ? null
                                      : () => action(() async {
                                          final data = await widget.api.call(
                                            'archivos/${item['id']}/url',
                                          );
                                          final uri = Uri.parse(data['url']);
                                          if (uri.scheme != 'https' ||
                                              !await launchUrl(
                                                uri,
                                                mode: LaunchMode
                                                    .externalApplication,
                                              )) {
                                            throw Exception(
                                              'No se pudo abrir el archivo.',
                                            );
                                          }
                                        }),
                                  child: const Text('Abrir archivo'),
                                ),
                              if (resource != 'qr')
                                TextButton(
                                  onPressed: busy
                                      ? null
                                      : () async {
                                          if (await confirm(
                                            context,
                                            '¿Eliminar este registro?',
                                          )) {
                                            await action(() async {
                                              await widget.api.call(
                                                '$resource/${item['id']}',
                                                method: 'DELETE',
                                              );
                                            });
                                          }
                                        },
                                  child: const Text('Eliminar'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
  );
}

class ScheduleEditor extends StatefulWidget {
  const ScheduleEditor({super.key, required this.resource});
  final String resource;
  @override
  State<ScheduleEditor> createState() => _ScheduleEditorState();
}

class _ScheduleEditorState extends State<ScheduleEditor> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController(), notes = TextEditingController();
  DateTime? start, end;
  int duration = 60, reminder = 1440;
  bool get session => widget.resource == 'sesiones';
  @override
  void dispose() {
    title.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<DateTime?> pick() async {
    final date = await showDatePicker(
      context: context,
      initialDate: start ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(start ?? DateTime.now()),
    );
    return time == null
        ? null
        : DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(session ? 'Nueva sesión' : 'Nueva cita')),
    body: Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: title,
            decoration: const InputDecoration(labelText: 'Título'),
            validator: (v) => v!.trim().isEmpty ? 'Ingresa un título' : null,
          ),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('Fecha y hora de inicio'),
            subtitle: Text(
              start == null
                  ? 'Seleccionar'
                  : dateLabel(start!.toIso8601String()),
            ),
            trailing: const Icon(Icons.calendar_month),
            onTap: () async {
              final value = await pick();
              if (value != null && mounted) setState(() => start = value);
            },
          ),
          if (!session)
            ListTile(
              title: const Text('Fin (opcional)'),
              subtitle: Text(
                end == null ? 'Seleccionar' : dateLabel(end!.toIso8601String()),
              ),
              onTap: () async {
                final value = await pick();
                if (value != null && mounted) setState(() => end = value);
              },
            ),
          if (session)
            DropdownButtonFormField<int>(
              initialValue: duration,
              decoration: const InputDecoration(labelText: 'Duración'),
              items: [15, 30, 60, 90, 120]
                  .map(
                    (v) =>
                        DropdownMenuItem(value: v, child: Text('$v minutos')),
                  )
                  .toList(),
              onChanged: (v) => setState(() => duration = v!),
            ),
          if (!session)
            DropdownButtonFormField<int>(
              initialValue: reminder,
              decoration: const InputDecoration(labelText: 'Recordatorio'),
              items: [60, 240, 1440, 2880]
                  .map(
                    (v) => DropdownMenuItem(
                      value: v,
                      child: Text('$v minutos antes'),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => reminder = v!),
            ),
          const SizedBox(height: 16),
          TextFormField(
            controller: notes,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Notas'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              if (!form.currentState!.validate()) return;
              if (start == null) {
                notify(context, 'Selecciona fecha y hora.');
                return;
              }
              if (end != null && !end!.isAfter(start!)) {
                notify(context, 'El fin debe ser posterior al inicio.');
                return;
              }
              Navigator.pop(context, <String, dynamic>{
                'titulo': title.text.trim(),
                'notas': notes.text.trim(),
                if (session) ...{
                  'fecha': start!.toIso8601String().substring(0, 10),
                  'hora_inicio':
                      '${start!.hour.toString().padLeft(2, '0')}:${start!.minute.toString().padLeft(2, '0')}',
                  'duracion_min': duration,
                } else ...{
                  'fecha_inicio': start!.toUtc().toIso8601String(),
                  'fecha_fin': end?.toUtc().toIso8601String(),
                  'recordatorio_min': reminder,
                },
              });
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    ),
  );
}

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key, required this.api});
  final Api api;
  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  late Future<Map<String, dynamic>> data;
  @override
  void initState() {
    super.initState();
    data = widget.api.call('admin/clientes');
  }

  Future<void> edit(Map<String, dynamic> client) async {
    final selected = Set<String>.from(client['modulos_visibles'] ?? []);
    final result = await showDialog<List<String>>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, update) => AlertDialog(
          title: Text('Permisos de ${client['nombre']}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final key in [
                  'panel',
                  'encuesta',
                  'sesiones',
                  'archivos',
                  'citas',
                  'qr',
                  'geocercas',
                ])
                  CheckboxListTile(
                    title: Text(key),
                    value: selected.contains(key),
                    onChanged: (v) => update(() {
                      if (v == true) {
                        selected.add(key);
                      } else {
                        selected.remove(key);
                      }
                    }),
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
              onPressed: () => Navigator.pop(c, selected.toList()),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    try {
      await widget.api.call(
        'admin/clientes/${client['id']}',
        method: 'PATCH',
        body: {'modulos_visibles': result},
      );
      if (mounted) setState(() => data = widget.api.call('admin/clientes'));
    } catch (e) {
      if (mounted) notify(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Clientes y permisos'),
      actions: [
        IconButton(
          onPressed: () =>
              setState(() => data = widget.api.call('admin/clientes')),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: data,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) return Center(child: Text('${snapshot.error}'));
        final clients = snapshot.data!['clientes'] as List;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (clients.isEmpty) const Text('No hay clientes registrados.'),
            for (final c in clients)
              Card(
                child: ListTile(
                  title: Text('${c['nombre'] ?? ''}'),
                  subtitle: Text(
                    '${c['email'] ?? ''}\n${c['necesidad'] ?? ''}',
                  ),
                  trailing: const Icon(Icons.tune),
                  onTap: () => edit(Map<String, dynamic>.from(c)),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class PasswordScreen extends StatefulWidget {
  const PasswordScreen({super.key, required this.api});
  final Api api;
  @override
  State<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends State<PasswordScreen> {
  final form = GlobalKey<FormState>();
  final password = TextEditingController(),
      confirmation = TextEditingController();
  bool busy = false;
  @override
  void dispose() {
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Cambiar contraseña')),
    body: Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextFormField(
            controller: password,
            obscureText: true,
            autofillHints: const [AutofillHints.newPassword],
            decoration: const InputDecoration(labelText: 'Nueva contraseña'),
            validator: (v) =>
                (v?.length ?? 0) < 8 ? 'Usa al menos 8 caracteres' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: confirmation,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Confirmar contraseña',
            ),
            validator: (v) =>
                v != password.text ? 'Las contraseñas no coinciden' : null,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    if (!form.currentState!.validate()) return;
                    setState(() => busy = true);
                    try {
                      await widget.api.auth.auth.updateUser(
                        UserAttributes(password: password.text),
                      );
                      if (context.mounted) {
                        notify(context, 'Contraseña actualizada');
                        if (Navigator.canPop(context)) Navigator.pop(context);
                      }
                    } catch (e) {
                      if (context.mounted) notify(context, e);
                    } finally {
                      if (mounted) setState(() => busy = false);
                    }
                  },
            child: Text(busy ? 'Guardando…' : 'Guardar contraseña'),
          ),
        ],
      ),
    ),
  );
}
