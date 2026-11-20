import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_a2/app/router.dart';
import 'package:mobile_a2/models/models.dart';
import 'package:mobile_a2/repositories/repositories.dart';
import 'package:mobile_a2/services/services.dart';
import 'package:mobile_a2/viewmodels/viewmodels.dart';
import 'package:mocktail/mocktail.dart';

class MockIgdbService extends Mock implements IIgdbService {}

void main() {
  late MockIgdbService mockService;
  late InMemoryGameRepository gameRepository;
  late SearchViewModel searchViewModel;
  late LibraryViewModel libraryViewModel;

  setUp(() {
    mockService = MockIgdbService();
    when(() => mockService.isFallbackMode).thenReturn(false);
    gameRepository = InMemoryGameRepository();
    searchViewModel = SearchViewModel(service: mockService);
    libraryViewModel = LibraryViewModel(repo: gameRepository);
  });

  tearDown(() {
    searchViewModel.dispose();
    libraryViewModel.dispose();
    gameRepository.dispose();
  });

  group('AppRouter - URLs Dedicadas por Página', () {
    test('Deve mapear "/" e "/home" para a Home View', () {
      final routeHome = AppRouter.onGenerateRoute(
        const RouteSettings(name: AppRoutes.home),
        igdbService: mockService,
        gameRepository: gameRepository,
        searchViewModel: searchViewModel,
        libraryViewModel: libraryViewModel,
      );

      expect(routeHome.settings.name, AppRoutes.home);

      final routeAlias = AppRouter.onGenerateRoute(
        const RouteSettings(name: '/home'),
        igdbService: mockService,
        gameRepository: gameRepository,
        searchViewModel: searchViewModel,
        libraryViewModel: libraryViewModel,
      );

      expect(routeAlias.settings.name, AppRoutes.home);
    });

    test('Deve mapear "/search" para a tela de Pesquisa', () {
      final route = AppRouter.onGenerateRoute(
        const RouteSettings(name: AppRoutes.search),
        igdbService: mockService,
        gameRepository: gameRepository,
        searchViewModel: searchViewModel,
        libraryViewModel: libraryViewModel,
      );

      expect(route.settings.name, AppRoutes.search);
    });

    test('Deve mapear "/library" para a tela da Biblioteca', () {
      final route = AppRouter.onGenerateRoute(
        const RouteSettings(name: AppRoutes.library),
        igdbService: mockService,
        gameRepository: gameRepository,
        searchViewModel: searchViewModel,
        libraryViewModel: libraryViewModel,
      );

      expect(route.settings.name, AppRoutes.library);
    });

    test('Deve mapear "/details?id=123" para a tela de Detalhes mantendo a NavigationBar fixa', () {
      const sample = Game(id: 123, name: 'The Witcher 3');
      final route = AppRouter.onGenerateRoute(
        const RouteSettings(name: AppRoutes.details, arguments: sample),
        igdbService: mockService,
        gameRepository: gameRepository,
        searchViewModel: searchViewModel,
        libraryViewModel: libraryViewModel,
      );

      expect(route.settings.name, '${AppRoutes.details}?id=123');
      expect(route.settings.arguments, sample);

      // Instancia o widget da rota para verificar que utiliza o MainNavigationShell
      final materialRoute = route as MaterialPageRoute;
      final widget = materialRoute.builder(MockBuildContext());
      expect(widget, isA<MainNavigationShell>());
      final shell = widget as MainNavigationShell;
      expect(shell.selectedGame, sample);
    });
  });
}

class MockBuildContext extends Mock implements BuildContext {}
