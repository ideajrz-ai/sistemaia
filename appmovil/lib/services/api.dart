import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class Api {
  Api(this.baseUrl, {http.Client? client}) : _client = client ?? http.Client();
  final String baseUrl;
  final http.Client _client;
  SupabaseClient get auth => Supabase.instance.client;

  Future<Map<String, dynamic>> call(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    var session = auth.auth.currentSession;
    if (session == null) throw Exception('Inicia sesión para continuar.');
    if (session.isExpired) session = (await auth.auth.refreshSession()).session;
    if (session == null)
      throw Exception('La sesión expiró. Inicia sesión otra vez.');
    final request = http.Request(
      method,
      Uri.parse('${baseUrl.replaceAll(RegExp(r"/+$"), "")}/api/$path'),
    );
    request.headers.addAll({
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${session.accessToken}',
    });
    if (body != null) request.body = jsonEncode(body);
    final response = await http.Response.fromStream(
      await _client.send(request).timeout(const Duration(seconds: 30)),
    ).timeout(const Duration(seconds: 30));
    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception(
        'El servidor no respondió con datos válidos (${response.statusCode}). Revisa la URL de la API.',
      );
    }
    if (response.statusCode >= 400)
      throw Exception(data['error'] ?? 'Error ${response.statusCode}');
    return data;
  }
}
