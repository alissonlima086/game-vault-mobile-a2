import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_a2/viewmodels/auth_viewmodel.dart';
import '../services/auth_service_test.dart';

void main() {
  group('AuthViewModel - Estados e Ciclo de Autenticação', () {
    late MockAuthService mockAuthService;
    late AuthViewModel viewModel;

    setUp(() {
      mockAuthService = MockAuthService();
      viewModel = AuthViewModel(authService: mockAuthService);
    });

    tearDown(() {
      viewModel.dispose();
      mockAuthService.dispose();
    });

    test('Estado inicial deve ser unauthenticated quando não há sessão prévia', () {
      expect(viewModel.status, equals(AuthStatus.unauthenticated));
      expect(viewModel.isAuthenticated, isFalse);
      expect(viewModel.currentUser, isNull);
      expect(viewModel.errorMessage, isNull);
    });

    test('Deve transitar para authenticating e depois authenticated com sucesso', () async {
      final future = viewModel.signInWithGoogle();

      expect(viewModel.status, equals(AuthStatus.authenticating));

      final success = await future;
      expect(success, isTrue);
      expect(viewModel.status, equals(AuthStatus.authenticated));
      expect(viewModel.isAuthenticated, isTrue);
      expect(viewModel.currentUser?.email, equals('aluno@universidade.edu.br'));
      expect(viewModel.errorMessage, isNull);
    });

    test('Deve transitar para status error quando signInWithGoogle falhar', () async {
      mockAuthService.shouldFail = true;

      final success = await viewModel.signInWithGoogle();
      expect(success, isFalse);
      expect(viewModel.status, equals(AuthStatus.error));
      expect(viewModel.isAuthenticated, isFalse);
      expect(viewModel.errorMessage, contains('Falha ao conectar com o Google'));
    });

    test('Deve transitar para unauthenticated ao chamar signOut', () async {
      await viewModel.signInWithGoogle();
      expect(viewModel.isAuthenticated, isTrue);

      await viewModel.signOut();
      expect(viewModel.status, equals(AuthStatus.unauthenticated));
      expect(viewModel.isAuthenticated, isFalse);
      expect(viewModel.currentUser, isNull);
    });
  });
}
