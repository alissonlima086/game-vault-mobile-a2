import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_a2/models/game.dart';
import 'package:mobile_a2/repositories/game_repository.dart';
import 'package:mobile_a2/services/igdb_service.dart';
import 'package:mobile_a2/viewmodels/game_details_viewmodel.dart';

class MockRecommendationService implements IIgdbService {
  @override
  bool get isFallbackMode => false;

  @override
  Future<List<Game>> searchGames(String query, {int limit = 20}) async => [];

  @override
  Future<List<Game>> getGamesByIds(List<int> ids) async {
    return ids.map((id) {
      return Game(
        id: id,
        name: 'Jogo Semelhante $id',
        summary: 'Recomendação baseada em $id',
        coverUrl: 'https://example.com/cover-$id.jpg',
        genres: const ['RPG'],
      );
    }).toList();
  }
}

void main() {
  group('GameDetailsViewModel - Recomendações de Jogos Semelhantes', () {
    late InMemoryGameRepository repository;
    late MockRecommendationService igdbService;

    final gameWithSimilar = Game(
      id: 100,
      name: 'Cyberpunk 2077',
      summary: 'RPG futurista em Night City',
      similarGames: const [1942, 2000, 3000],
    );

    setUp(() {
      repository = InMemoryGameRepository();
      igdbService = MockRecommendationService();
    });

    test('Deve carregar recomendações de jogos semelhantes via serviço IGDB', () async {
      final viewModel = GameDetailsViewModel(
        game: gameWithSimilar,
        repo: repository,
        igdbService: igdbService,
      );

      // Espera inicialização assíncrona
      await Future.delayed(const Duration(milliseconds: 10));

      expect(viewModel.similarGames, hasLength(3));
      expect(viewModel.similarGames.first.name, equals('Jogo Semelhante 1942'));
      expect(viewModel.loadingSimilar, isFalse);

      viewModel.dispose();
    });

    test('Deve manter lista de semelhantes vazia se game não possuir similarGames', () async {
      final gameWithoutSimilar = Game(
        id: 101,
        name: 'Jogo Indie Único',
        similarGames: const [],
      );

      final viewModel = GameDetailsViewModel(
        game: gameWithoutSimilar,
        repo: repository,
        igdbService: igdbService,
      );

      await Future.delayed(const Duration(milliseconds: 10));

      expect(viewModel.similarGames, isEmpty);
      expect(viewModel.loadingSimilar, isFalse);

      viewModel.dispose();
    });
  });
}
