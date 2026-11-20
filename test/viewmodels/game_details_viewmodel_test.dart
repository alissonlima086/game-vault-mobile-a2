import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_a2/models/game.dart';
import 'package:mobile_a2/repositories/game_repository.dart';
import 'package:mobile_a2/viewmodels/game_details_viewmodel.dart';
import 'package:mocktail/mocktail.dart';

class MockGameRepository extends Mock implements IGameRepository {}

void main() {
  late MockGameRepository mockRepo;
  const testGame = Game(id: 10, name: 'Hades');

  setUp(() {
    mockRepo = MockGameRepository();
  });

  group('GameDetailsViewModel', () {
    test('Deve inicializar status do jogo a partir do repositório', () async {
      when(() => mockRepo.getGameById(10)).thenAnswer(
        (_) async => LibraryEntry(
          game: testGame,
          status: GameStatus.playing,
          addedAt: DateTime.now(),
        ),
      );

      final vm = GameDetailsViewModel(game: testGame, repo: mockRepo);
      // Aguarda microtask para loadStatus
      await Future.delayed(Duration.zero);

      expect(vm.isInLibrary, isTrue);
      expect(vm.selectedStatus, GameStatus.playing);
    });

    test('Deve permitir alterar status selecionado localmente', () async {
      when(() => mockRepo.getGameById(10)).thenAnswer((_) async => null);

      final vm = GameDetailsViewModel(game: testGame, repo: mockRepo);
      await Future.delayed(Duration.zero);

      expect(vm.isInLibrary, isFalse);
      expect(vm.selectedStatus, GameStatus.wishlist);

      vm.setSelectedStatus(GameStatus.completed);
      expect(vm.selectedStatus, GameStatus.completed);
    });

    test('Deve salvar na biblioteca e atualizar estado', () async {
      when(() => mockRepo.getGameById(10)).thenAnswer((_) async => null);
      when(() => mockRepo.saveGame(testGame, GameStatus.owned, notes: any(named: 'notes'), userRating: any(named: 'userRating')))
          .thenAnswer((_) async {});

      final vm = GameDetailsViewModel(game: testGame, repo: mockRepo);
      await Future.delayed(Duration.zero);

      vm.setSelectedStatus(GameStatus.owned);

      // Ao salvar, getGameById retornará a entrada recém-salva
      when(() => mockRepo.getGameById(10)).thenAnswer(
        (_) async => LibraryEntry(
          game: testGame,
          status: GameStatus.owned,
          addedAt: DateTime.now(),
        ),
      );

      final success = await vm.saveToLibrary(notes: 'Excelente jogo');
      expect(success, isTrue);
      expect(vm.isInLibrary, isTrue);
      expect(vm.feedbackMessage, contains('adicionado'));
    });

    test('Deve remover jogo da biblioteca', () async {
      when(() => mockRepo.getGameById(10)).thenAnswer(
        (_) async => LibraryEntry(
          game: testGame,
          status: GameStatus.playing,
          addedAt: DateTime.now(),
        ),
      );
      when(() => mockRepo.removeGame(10)).thenAnswer((_) async {});

      final vm = GameDetailsViewModel(game: testGame, repo: mockRepo);
      await Future.delayed(Duration.zero);

      expect(vm.isInLibrary, isTrue);

      final success = await vm.removeFromLibrary();
      expect(success, isTrue);
      expect(vm.isInLibrary, isFalse);
      expect(vm.feedbackMessage, contains('removido'));
    });
  });
}
