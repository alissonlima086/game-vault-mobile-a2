import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_a2/models/game.dart';
import 'package:mobile_a2/repositories/game_repository.dart';

void main() {
  group('InMemoryGameRepository', () {
    late InMemoryGameRepository repository;

    const testGame1 = Game(id: 1, name: 'Warframe');
    const testGame2 = Game(id: 2, name: 'Elden Ring');

    setUp(() {
      repository = InMemoryGameRepository();
    });

    tearDown(() {
      repository.dispose();
    });

    test('Deve iniciar com biblioteca vazia', () async {
      final games = await repository.getLibraryGames();
      expect(games, isEmpty);
    });

    test('Deve salvar jogo e recuperar por ID', () async {
      await repository.saveGame(
        testGame1,
        GameStatus.playing,
        notes: 'Espadas e tiros espaciais',
      );

      final inLibrary = await repository.isGameInLibrary(1);
      expect(inLibrary, isTrue);

      final entry = await repository.getGameById(1);
      expect(entry, isNotNull);
      expect(entry!.game.name, 'Warframe');
      expect(entry.status, GameStatus.playing);
      expect(entry.notes, 'Espadas e tiros espaciais');
    });

    test('Deve atualizar status de jogo existente', () async {
      await repository.saveGame(testGame1, GameStatus.wishlist);
      var entry = await repository.getGameById(1);
      expect(entry!.status, GameStatus.wishlist);

      await repository.updateGameStatus(1, GameStatus.completed);
      entry = await repository.getGameById(1);
      expect(entry!.status, GameStatus.completed);
    });

    test('Deve remover jogo da biblioteca', () async {
      await repository.saveGame(testGame1, GameStatus.owned);
      await repository.saveGame(testGame2, GameStatus.playing);

      var list = await repository.getLibraryGames();
      expect(list.length, 2);

      await repository.removeGame(1);
      list = await repository.getLibraryGames();
      expect(list.length, 1);
      expect(list.first.game.id, 2);

      final inLibrary = await repository.isGameInLibrary(1);
      expect(inLibrary, isFalse);
    });

    test('Deve emitir mudanças no Stream de libraryChanges', () async {
      expectLater(
        repository.libraryChanges,
        emitsInOrder([
          predicate<List<LibraryEntry>>((list) => list.length == 1 && list.first.game.id == 1),
          predicate<List<LibraryEntry>>((list) => list.length == 2),
        ]),
      );

      await repository.saveGame(testGame1, GameStatus.wishlist);
      await repository.saveGame(testGame2, GameStatus.playing);
    });
  });
}
