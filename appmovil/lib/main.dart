import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'services/api.dart';
import 'screens/workspace_screen.dart';

const orange = Color(0xfff97316);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final config = AppConfig(
    const String.fromEnvironment('SUPABASE_URL', defaultValue: '').isNotEmpty
        ? const String.fromEnvironment('SUPABASE_URL')
        : prefs.getString('supabase_url') ?? '',
    const String.fromEnvironment(
          'SUPABASE_ANON_KEY',
          defaultValue: '',
        ).isNotEmpty
        ? const String.fromEnvironment('SUPABASE_ANON_KEY')
        : prefs.getString('supabase_key') ?? '',
    const String.fromEnvironment('API_URL', defaultValue: '').isNotEmpty
        ? const String.fromEnvironment('API_URL')
        : prefs.getString('api_url') ?? '',
  );
  runApp(MyApp(config: config));
}

class AppConfig {
  const AppConfig(this.url, this.key, this.apiUrl);
  final String url, key, apiUrl;
  bool get valid => validUrl(url) && publicKey(key) && validUrl(apiUrl);
  static bool publicKey(String value) {
    if (value.startsWith('sb_publishable_')) return value.length > 20;
    try {
      final parts = value.split('.');
      if (parts.length != 3) return false;
      final claims = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      return claims is Map && claims['role'] == 'anon';
    } catch (_) {
      return false;
    }
  }

  static bool validUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        uri.query.isEmpty &&
        uri.fragment.isEmpty;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.config = const AppConfig('', '', '')});
  final AppConfig config;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'SistemaIA',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: orange,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xff0b0b0c),
      useMaterial3: true,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xff17181a)),
    ),
    home: Bootstrap(config: config),
  );
}

class Bootstrap extends StatefulWidget {
  const Bootstrap({super.key, required this.config});
  final AppConfig config;
  @override
  State<Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<Bootstrap> {
  bool ready = false, busy = false;
  String? error;
  late final url = TextEditingController(text: widget.config.url);
  late final key = TextEditingController(text: widget.config.key);
  late final apiUrl = TextEditingController(text: widget.config.apiUrl);
  @override
  void initState() {
    super.initState();
    if (widget.config.valid) unawaited(connect());
  }

  @override
  void dispose() {
    url.dispose();
    key.dispose();
    apiUrl.dispose();
    super.dispose();
  }

  Future<void> connect() async {
    if (!AppConfig(
      url.text.trim(),
      key.text.trim(),
      apiUrl.text.trim(),
    ).valid) {
      setState(
        () => error = 'Ingresa URLs HTTPS y la clave pública de Supabase.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await Supabase.initialize(
        url: url.text.trim(),
        publishableKey: key.text.trim(),
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('supabase_url', url.text.trim());
      await prefs.setString('supabase_key', key.text.trim());
      await prefs.setString('api_url', apiUrl.text.trim());
      if (mounted) setState(() => ready = true);
    } catch (_) {
      if (mounted)
        setState(
          () => error =
              'No se pudo iniciar la conexión. Revisa la configuración.',
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ready) return AuthGate(api: Api(apiUrl.text.trim()));
    return Scaffold(
      appBar: AppBar(title: const Text('Conectar SistemaIA')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.business, size: 64, color: orange),
                const SizedBox(height: 16),
                const Text(
                  'Configura la conexión de tu organización. Usa únicamente la clave pública (anon o publishable).',
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: url,
                  decoration: const InputDecoration(
                    labelText: 'URL HTTPS de Supabase',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: key,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Clave pública de Supabase',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: apiUrl,
                  decoration: const InputDecoration(
                    labelText: 'URL HTTPS de la API (sin /api)',
                  ),
                ),
                const SizedBox(height: 12),
                if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.redAccent)),
                FilledButton(
                  onPressed: busy ? null : connect,
                  child: Text(busy ? 'Conectando…' : 'Conectar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.api});
  final Api api;
  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
    stream: api.auth.auth.onAuthStateChange,
    builder: (context, snapshot) {
      final user = api.auth.auth.currentUser;
      return user == null
          ? LoginScreen(api: api)
          : WorkspaceScreen(key: ValueKey(user.id), api: api);
    },
  );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.api});
  final Api api;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController(),
      password = TextEditingController(),
      name = TextEditingController();
  bool registering = false, busy = false;
  String? message;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    name.dispose();
    super.dispose();
  }

  Future<void> submit({bool reset = false}) async {
    if (reset ? !email.text.contains('@') : !form.currentState!.validate())
      return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final auth = widget.api.auth.auth;
      if (reset) {
        await auth.resetPasswordForEmail(email.text.trim());
      } else if (registering) {
        await auth.signUp(
          email: email.text.trim(),
          password: password.text,
          data: {'nombre': name.text.trim()},
        );
      } else {
        await auth.signInWithPassword(
          email: email.text.trim(),
          password: password.text,
        );
      }
      if (mounted)
        setState(
          () => message = reset
              ? 'Revisa tu correo para recuperar el acceso.'
              : registering
              ? 'Cuenta creada. Revisa tu correo si se solicita confirmación.'
              : null,
        );
    } on AuthException catch (e) {
      if (mounted) setState(() => message = e.message);
    } catch (_) {
      if (mounted)
        setState(
          () => message = 'No se pudo conectar. Revisa tu conexión a internet.',
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('SistemaIA · Consultoría')),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.business, size: 72, color: orange),
                const SizedBox(height: 24),
                Text(
                  registering ? 'Crear cuenta' : 'Iniciar sesión',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 24),
                if (registering) ...[
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                    validator: (v) =>
                        v!.trim().isEmpty ? 'Ingresa tu nombre' : null,
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                  ),
                  validator: (v) =>
                      v != null &&
                          RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                              .hasMatch(v.trim())
                      ? null
                      : 'Ingresa un correo válido',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: password,
                  obscureText: true,
                  autofillHints: [
                    registering
                        ? AutofillHints.newPassword
                        : AutofillHints.password,
                  ],
                  decoration: const InputDecoration(labelText: 'Contraseña'),
                  validator: (v) =>
                      (v?.length ?? 0) < 6 ? 'Usa al menos 6 caracteres' : null,
                ),
                const SizedBox(height: 16),
                if (message != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(message!),
                  ),
                FilledButton(
                  onPressed: busy ? null : submit,
                  child: Text(
                    busy
                        ? 'Conectando…'
                        : registering
                        ? 'Registrarme'
                        : 'Entrar',
                  ),
                ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () => setState(() {
                          registering = !registering;
                          message = null;
                        }),
                  child: Text(
                    registering ? 'Ya tengo cuenta' : 'Crear una cuenta',
                  ),
                ),
                TextButton(
                  onPressed: busy ? null : () => submit(reset: true),
                  child: const Text('Recuperar contraseña'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
