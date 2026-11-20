import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user.dart';

export '../models/user.dart';

/// Autenticação
abstract class IAuthService {
  /// Alteração no estado da sessão do usuário
  Stream<AppUser?> get authStateChanges;

  /// Usuario autenticado
  AppUser? get currentUser;

  /// Indica se há uma sessão ativa.
  bool get isAuthenticated;

  /// Autenticação com Google OAuth2.
  Future<bool> signInWithGoogle();

  /// Encerrar a sessão
  Future<void> signOut();
}

/// Autenticação com o Supabase Auth.
class SupabaseAuthService implements IAuthService {
  final SupabaseClient? _supabaseClient;

  SupabaseAuthService({SupabaseClient? client}) : _supabaseClient = client;

  SupabaseClient? get _client {
    if (_supabaseClient != null) return _supabaseClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<AppUser?> get authStateChanges {
    final client = _client;
    if (client == null) {
      return Stream.value(null);
    }

    return client.auth.onAuthStateChange.map((data) {
      final user = data.session?.user ?? client.auth.currentUser;
      if (user == null) return null;
      return AppUser.fromSupabaseUser(user);
    });
  }

  @override
  AppUser? get currentUser {
    final user = _client?.auth.currentUser;
    if (user == null) return null;
    return AppUser.fromSupabaseUser(user);
  }

  @override
  bool get isAuthenticated => currentUser != null;

  @override
  Future<bool> signInWithGoogle() async {
    final client = _client;
    if (client == null) {
      debugPrint('[AuthService] Supabase não inicializado. Não é possível iniciar OAuth.');
      return false;
    }

    // Configuração de redirecionamento conforme especificação do projeto:
    // Web: http://localhost:3000/**
    final redirectTo = kIsWeb
        ? 'http://localhost:3000/'
        : 'br.edu.exemplo.auth://login-callback/';

    try {
      final success = await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectTo,
      );
      return success;
    } catch (e) {
      debugPrint('[AuthService] Erro no fluxo de login Google OAuth2: $e');
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    final client = _client;
    if (client == null) return;

    try {
      await client.auth.signOut();
    } catch (e) {
      debugPrint('[AuthService] Erro ao deslogar: $e');
      rethrow;
    }
  }
}
