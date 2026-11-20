import 'dart:async';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

enum AuthStatus {
  initial,
  authenticating,
  authenticated,
  unauthenticated,
  error,
}

/// ViewModel responsável pelo gerenciamento de estado da sessão do usuário.
class AuthViewModel extends ChangeNotifier {
  final IAuthService authService;
  StreamSubscription<AppUser?>? _subscription;

  AuthStatus _status = AuthStatus.initial;
  AppUser? _currentUser;
  String? _errorMessage;

  AuthViewModel({required this.authService}) {
    _init();
  }

  AuthStatus get status => _status;
  AppUser? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated && _currentUser != null;

  void _init() {
    _currentUser = authService.currentUser;
    _status = _currentUser != null
        ? AuthStatus.authenticated
        : AuthStatus.unauthenticated;

    _subscription = authService.authStateChanges.listen(
      (user) {
        _currentUser = user;
        _status = user != null
            ? AuthStatus.authenticated
            : AuthStatus.unauthenticated;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (error) {
        _errorMessage = error.toString();
        _status = AuthStatus.error;
        notifyListeners();
      },
    );
  }

  /// Inicia o fluxo de autenticação com Google
  Future<bool> signInWithGoogle() async {
    _status = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      final started = await authService.signInWithGoogle();
      if (!started && _currentUser == null) {
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return false;
      }
      return true;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = 'Falha ao conectar com o Google: $e';
      notifyListeners();
      return false;
    }
  }

  /// Encerra a sessão do usuário
  Future<void> signOut() async {
    try {
      await authService.signOut();
      _currentUser = null;
      _status = AuthStatus.unauthenticated;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Falha ao encerrar sessão: $e';
    } finally {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
