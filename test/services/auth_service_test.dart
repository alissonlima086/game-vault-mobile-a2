import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_a2/services/auth_service.dart';

class MockAuthService implements IAuthService {
  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _user;
  bool shouldFail = false;

  @override
  Stream<AppUser?> get authStateChanges => _controller.stream;

  @override
  AppUser? get currentUser => _user;

  @override
  bool get isAuthenticated => _user != null;

  @override
  Future<bool> signInWithGoogle() async {
    if (shouldFail) {
      throw Exception('Falha de rede ao conectar com Google');
    }
    _user = const AppUser(
      id: 'mock-user-123',
      email: 'aluno@universidade.edu.br',
      name: 'Aluno Exemplo',
      avatarUrl: 'https://example.com/avatar.png',
    );
    _controller.add(_user);
    return true;
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _controller.add(null);
  }

  void dispose() {
    _controller.close();
  }
}

void main() {
  group('AppUser Model', () {
    test('Deve extrair displayName preferencialmente do name', () {
      const user = AppUser(
        id: '1',
        email: 'dev@teste.com',
        name: 'Dev Mobile',
      );
      expect(user.displayName, equals('Dev Mobile'));
    });

    test('Deve utilizar prefixo do e-mail se name for nulo ou vazio', () {
      const user1 = AppUser(
        id: '1',
        email: 'alisson@ufms.br',
      );
      expect(user1.displayName, equals('alisson'));

      const user2 = AppUser(
        id: '2',
        email: 'gamer@provedor.com',
        name: '   ',
      );
      expect(user2.displayName, equals('gamer'));
    });

    test('Deve retornar fallback se email e name forem vazios', () {
      const user = AppUser(
        id: '1',
        email: '',
      );
      expect(user.displayName, equals('Jogador'));
    });
  });

  group('MockAuthService Contract', () {
    late MockAuthService service;

    setUp(() {
      service = MockAuthService();
    });

    tearDown(() {
      service.dispose();
    });

    test('Deve iniciar desautenticado', () {
      expect(service.isAuthenticated, isFalse);
      expect(service.currentUser, isNull);
    });

    test('Deve autenticar com Google e emitir na stream', () async {
      expectLater(
        service.authStateChanges,
        emits(isA<AppUser>().having((u) => u.email, 'email', 'aluno@universidade.edu.br')),
      );

      final success = await service.signInWithGoogle();
      expect(success, isTrue);
      expect(service.isAuthenticated, isTrue);
      expect(service.currentUser?.name, equals('Aluno Exemplo'));
    });

    test('Deve deslogar com signOut e emitir null na stream', () async {
      await service.signInWithGoogle();
      expect(service.isAuthenticated, isTrue);

      expectLater(service.authStateChanges, emits(isNull));

      await service.signOut();
      expect(service.isAuthenticated, isFalse);
      expect(service.currentUser, isNull);
    });
  });
}
