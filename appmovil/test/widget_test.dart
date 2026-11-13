import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appmovil/main.dart';
import 'package:appmovil/services/api.dart';
import 'package:appmovil/screens/workspace_screen.dart';

void main() {
  testWidgets('Solicita configuración y rechaza URLs incompletas', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('Conectar SistemaIA'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Conectar'));
    await tester.pump();
    expect(
      find.text('Ingresa URLs HTTPS y la clave pública de Supabase.'),
      findsOneWidget,
    );
  });
  test('La conexión requiere HTTPS', () {
    expect(AppConfig.validUrl('https://api.example.com'), isTrue);
    expect(AppConfig.validUrl('http://api.example.com'), isFalse);
    expect(AppConfig.validUrl('https://'), isFalse);
    expect(
      AppConfig.validUrl('https://user:password@api.example.com'),
      isFalse,
    );
  });
  test('Rechaza claves privadas en la app', () {
    expect(AppConfig.publicKey('sb_secret_12345678901234567890'), isFalse);
    expect(AppConfig.publicKey('sb_publishable_12345678901234567890'), isTrue);
    expect(AppConfig.publicKey('valor-invalido'), isFalse);
  });
  testWidgets('Una cita no se guarda sin título y fecha', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ScheduleEditor(resource: 'citas')),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pump();
    expect(find.text('Ingresa un título'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Consultoría');
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pump();
    expect(find.text('Selecciona fecha y hora.'), findsOneWidget);
  });
  testWidgets('Rechaza contraseñas cortas y confirmaciones diferentes', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: PasswordScreen(api: Api('https://example.com'))),
    );
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.first, 'corta');
    await tester.enterText(fields.last, 'diferente');
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar contraseña'));
    await tester.pump();
    expect(find.text('Usa al menos 8 caracteres'), findsOneWidget);
    expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
  });
}
