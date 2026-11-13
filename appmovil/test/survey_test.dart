import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:appmovil/services/api.dart';
import 'package:appmovil/screens/survey_screen.dart';

class SurveyApi extends Api {
  SurveyApi() : super('https://example.com');
  Map<String, dynamic>? submitted;
  @override
  Future<Map<String, dynamic>> call(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    if (path.startsWith('preguntas')) {
      return {
        'preguntas': [
          {
            'id': 'q1',
            'texto': '¿Necesitas consultoría?',
            'tipo': 'si_no',
            'obligatoria': true,
          },
        ],
      };
    }
    if (method == 'POST') {
      submitted = body;
      return {
        'encuesta': {
          'diagnostico': 'Necesidad detectada',
          'recomendaciones': 'Agendar una sesión',
          'created_at': '2026-11-13T12:00:00Z',
        },
      };
    }
    return {'encuestas': []};
  }
}

void main() {
  testWidgets(
    'Valida obligatorias y envía valores reales para generar diagnóstico',
    (tester) async {
      final api = SurveyApi();
      await tester.pumpWidget(MaterialApp(home: SurveyScreen(api: api)));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Enviar y generar diagnóstico'),
      );
      await tester.pumpAndSettle();
      expect(api.submitted, isNull);
      expect(find.text('Responde: ¿Necesitas consultoría?'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Sí'));
      await tester.tap(
        find.widgetWithText(FilledButton, 'Enviar y generar diagnóstico'),
      );
      await tester.pumpAndSettle();
      expect(api.submitted, {
        'respuestas': [
          {'pregunta_id': 'q1', 'respuesta': 'si'},
        ],
      });
      expect(find.text('Necesidad detectada'), findsWidgets);
      expect(find.text('Agendar una sesión'), findsWidgets);
    },
  );
}
