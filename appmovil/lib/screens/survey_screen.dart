import 'package:material_ui/material_ui.dart';

import '../services/api.dart';
import 'workspace_screen.dart';

class SurveyScreen extends StatefulWidget {
  const SurveyScreen({super.key, required this.api});
  final Api api;
  @override
  State<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> {
  final answers = <String, dynamic>{};
  List<dynamic> questions = [], history = [];
  bool loading = true, sending = false;
  String? error;
  Map<String, dynamic>? result;
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
      final data = await Future.wait([
        widget.api.call('preguntas?activas=1'),
        widget.api.call('encuestas'),
      ]);
      if (mounted)
        setState(() {
          questions = data[0]['preguntas'];
          history = data[1]['encuestas'];
        });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> send() async {
    for (final p in questions) {
      final value = answers[p['id']];
      if (p['obligatoria'] == true &&
          (value == null ||
              value is String && value.trim().isEmpty ||
              value is List && value.isEmpty)) {
        notify(context, 'Responde: ${p['texto']}');
        return;
      }
    }
    setState(() => sending = true);
    try {
      final data = await widget.api.call(
        'encuestas',
        method: 'POST',
        body: {
          'respuestas': [
            for (final p in questions)
              {'pregunta_id': p['id'], 'respuesta': answers[p['id']]},
          ],
        },
      );
      if (mounted)
        setState(() {
          result = data['encuesta'];
          history.insert(0, result);
        });
    } catch (e) {
      if (mounted) notify(context, e);
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Widget question(Map<String, dynamic> p) {
    final id = p['id'] as String;
    final type = p['tipo'];
    final options = type == 'si_no'
        ? ['si', 'no']
        : type == 'escala'
        ? List.generate(10, (i) => i + 1)
        : List<dynamic>.from(p['opciones'] ?? []);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${p['texto']}${p['obligatoria'] == true ? ' *' : ''}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (type == 'opcion_multiple')
              for (final option in options)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('$option'),
                  value: (answers[id] as List? ?? []).contains(option),
                  onChanged: sending
                      ? null
                      : (checked) => setState(() {
                          final values = List<dynamic>.from(answers[id] ?? []);
                          if (checked == true) {
                            values.add(option);
                          } else {
                            values.remove(option);
                          }
                          answers[id] = values;
                        }),
                )
            else if (['si_no', 'opcion_unica', 'escala'].contains(type))
              Wrap(
                spacing: 8,
                children: [
                  for (final option in options)
                    ChoiceChip(
                      label: Text(option == 'si' ? 'Sí' : '$option'),
                      selected: answers[id] == option,
                      onSelected: sending
                          ? null
                          : (_) => setState(() => answers[id] = option),
                    ),
                ],
              )
            else
              TextFormField(
                key: ValueKey(id),
                initialValue: answers[id]?.toString(),
                enabled: !sending,
                keyboardType: type == 'numero'
                    ? const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      )
                    : TextInputType.multiline,
                maxLines: type == 'numero' ? 1 : 3,
                decoration: const InputDecoration(labelText: 'Tu respuesta'),
                onChanged: (value) => answers[id] = type == 'numero'
                    ? num.tryParse(value.replaceAll(',', '.'))
                    : value.trim(),
              ),
          ],
        ),
      ),
    );
  }

  Widget diagnosis(Map<String, dynamic> value) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Diagnóstico · ${dateLabel(value['created_at'])}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          SelectableText('${value['diagnostico'] ?? 'Sin diagnóstico'}'),
          const SizedBox(height: 16),
          const Text(
            'Recomendaciones',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SelectableText('${value['recomendaciones'] ?? ''}'),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Encuesta y diagnóstico'),
      actions: [
        IconButton(
          onPressed: sending ? null : load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(error!),
                TextButton(onPressed: load, child: const Text('Reintentar')),
              ],
            ),
          )
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (result != null) ...[
                diagnosis(result!),
                FilledButton(
                  onPressed: () => setState(() {
                    result = null;
                    answers.clear();
                  }),
                  child: const Text('Responder otra encuesta'),
                ),
              ] else ...[
                const Text(
                  'Responde las preguntas para generar tu diagnóstico. * Obligatoria.',
                ),
                if (questions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No hay preguntas activas.'),
                  ),
                for (final p in questions)
                  question(Map<String, dynamic>.from(p)),
                if (questions.isNotEmpty)
                  FilledButton(
                    onPressed: sending ? null : send,
                    child: Text(
                      sending ? 'Enviando…' : 'Enviar y generar diagnóstico',
                    ),
                  ),
              ],
              const SizedBox(height: 24),
              Text(
                'Mis encuestas',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              for (final entry in history)
                diagnosis(Map<String, dynamic>.from(entry)),
            ],
          ),
  );
}
