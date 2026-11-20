import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_a2/models/game.dart';
import 'package:mobile_a2/repositories/game_repository.dart';
import 'package:mobile_a2/repositories/supabase_game_repository.dart';

void main() {
  group('SupabaseGameRepository (Fallback & Operações Locais)', () {
    late InMemoryGameRepository fallback;
    late SupabaseGameRepository repository;

    final sampleGame = Game(
      id: 999,
      name: 'Elden Ring',
      summary: 'Action RPG by FromSoftware',
      coverUrl: 'https://example.com/cover.jpg',
      genres: const ['RPG', 'Action'],
      similarGames: const [1942, 1111],
    );

    setUp(() {
      fallback = InMemoryGameRepository();
      repository = SupabaseGameRepository(localFallback: fallback);
    });

    tearDown(() {
      repository.dispose();
    });

    test('Deve iniciar com lista de jogos vazia em fallback', () async {
      final games = await repository.getLibraryGames();
      expect(games, isEmpty);
    });

    test('Deve salvar e recuperar jogo via fallback', () async {
      await repository.saveGame(
        sampleGame,
        GameStatus.playing,
        notes: 'Jogando com build de Fé',
        userRating: 9,
      );

      final entry = await repository.getGameById(999);
      expect(entry, isNotNull);
      expect(entry!.game.name, equals('Elden Ring'));
      expect(entry.status, equals(GameStatus.playing));
      expect(entry.notes, equals('Jogando com build de Fé'));
      expect(entry.userRating, equals(9));

      final isInLib = await repository.isGameInLibrary(999);
      expect(isInLib, isTrue);
    });

    test('Deve atualizar status do jogo existente', () async {
      await repository.saveGame(sampleGame, GameStatus.wishlist);
      await repository.updateGameStatus(999, GameStatus.completed);

      final entry = await repository.getGameById(999);
      expect(entry!.status, equals(GameStatus.completed));
    });

    test('Deve remover jogo da biblioteca', () async {
      await repository.saveGame(sampleGame, GameStatus.owned);
      expect(await repository.isGameInLibrary(999), isTrue);

      await repository.removeGame(999);
      expect(await repository.isGameInLibrary(999), isFalse);
    });

    test('Deve emitir atualizações no stream de libraryChanges', () async {
      expectLater(
        repository.libraryChanges,
        emits(hasLength(1)),
      );

      await repository.saveGame(sampleGame, GameStatus.wishlist);
    });
  });
}
