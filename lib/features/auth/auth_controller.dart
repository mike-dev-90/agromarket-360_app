import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';

class AppUser {
  AppUser({required this.id, required this.name, required this.email, required this.identityVerified});

  final int id;
  final String name;
  final String email;
  final bool identityVerified;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as int,
        name: json['name'] as String,
        email: json['email'] as String,
        identityVerified: json['identity_verified'] == true,
      );
}

/// Usuario autenticado (null = invitado). Carga la sesión guardada al arrancar.
class AuthController extends AsyncNotifier<AppUser?> {
  ApiClient get _api => ref.read(apiClientProvider);

  @override
  Future<AppUser?> build() async {
    final token = await _api.tokens.read();
    if (token == null) return null;
    try {
      final body = await _api.get('/auth/me');
      return AppUser.fromJson(body['user'] as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.statusCode == 401) await _api.tokens.clear();
      return null;
    }
  }

  Future<void> login(String email, String password) async {
    final body = await _api.post('/auth/login', data: {'email': email, 'password': password, 'device_name': 'app-android'});
    await _saveSession(body);
  }

  Future<void> register(Map<String, String> data) async {
    final body = await _api.post('/auth/register', data: {...data, 'device_name': 'app-android'});
    await _saveSession(body);
  }

  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } on ApiException {
      // Si no hay red, igualmente se cierra la sesión local.
    }
    await _api.tokens.clear();
    state = const AsyncData(null);
  }

  Future<void> _saveSession(Map<String, dynamic> body) async {
    await _api.tokens.write(body['token'] as String);
    state = AsyncData(AppUser.fromJson(body['user'] as Map<String, dynamic>));
  }
}

final authProvider = AsyncNotifierProvider<AuthController, AppUser?>(AuthController.new);
