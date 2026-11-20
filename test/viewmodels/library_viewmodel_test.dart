import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_a2/models/game.dart';
import 'package:mobile_a2/repositories/game_repository.dart';
import 'package:mobile_a2/viewmodels/library_viewmodel.dart';
import 'package:mocktail/mocktail.dart';

class MockGameRepository extends Mock implements IGameRepository {}

void main() {
  late MockGameRepository mockRepo;
  late StreamController<List<LibraryEntry>> streamController;

  const game1 = Game(id: 1, name: 'Game A');
  const game2 = Game(id: 2, name: 'Game B');
  const game3 = Game(id: 3, name: 'Game C');

  final entry1 = LibraryEntry(game: game1, status: GameStatus.wishlist, addedAt: DateTime.now());
  final entry2 = LibraryEntry(game: game2, status: GameStatus.playing, addedAt: DateTime.now());
  final entry3 = LibraryEntry(game: game3, status: GameStatus.completed, addedAt: DateTime.now());

  setUp(() {
    mockRepo = MockGameRepository();
    streamController = StreamController<List<LibraryEntry>>.broadcast();
    when(() => mockRepo.libraryChanges).thenAnswer((_) => streamController.stream);
  });

  tearDown(() {
    streamController.close();
  });

  group('LibraryViewModel', () {
    test('Deve carregar entradas e calcular contadores por status', () async {
      when(() => mockRepo.getLibraryGames()).thenAnswer((_) async => [entry1, entry2, entry3]);

      final vm = LibraryViewModel(repo: mockRepo);
      await Future.delayed(Duration.zero);

      expect(vm.totalCount, 3);
      expect(vm.countForStatus(GameStatus.wishlist), 1);
      expect(vm.countForStatus(GameStatus.playing), 1);
      expect(vm.countForStatus(GameStatus.completed), 1);
      expect(vm.countForStatus(GameStatus.owned), 0);
    });

    test('Deve filtrar entradas quando um status for selecionado', () async {
      when(() => mockRepo.getLibraryGames()).thenAnswer((_) async => [entry1, entry2, entry3]);

      final vm = LibraryViewModel(repo: mockRepo);
      await Future.delayed(Duration.zero);

      expect(vm.filteredEntries.length, 3);

      vm.setFilter(GameStatus.playing);
      expect(vm.filteredEntries.length, 1);
      expect(vm.filteredEntries.first.game.id, 2);

      vm.setFilter(GameStatus.owned);
      expect(vm.filteredEntries, isEmpty);

      vm.setFilter(null);
      expect(vm.filteredEntries.length, 3);
    });

    test('Deve reagir automaticamente ao stream de libraryChanges', () async {
      when(() => mockRepo.getLibraryGames()).thenAnswer((_) async => [entry1]);

      final vm = LibraryViewModel(repo: mockRepo);
      await Future.delayed(Duration.zero);
      expect(vm.totalCount, 1);

      // Simula alteração remota/local emitida pelo repositório
      streamController.add([entry1, entry2]);
      await Future.delayed(Duration.zero);

      expect(vm.totalCount, 2);
    });

    test('Deve retornar até 4 jogos adicionados recentemente ordenados por data decrescente', () async {
      final now = DateTime.now();
      final e1 = LibraryEntry(game: const Game(id: 1, name: 'G1'), status: GameStatus.playing, addedAt: now.subtract(const Duration(days: 5)));
      final e2 = LibraryEntry(game: const Game(id: 2, name: 'G2'), status: GameStatus.playing, addedAt: now.subtract(const Duration(days: 1)));
      final e3 = LibraryEntry(game: const Game(id: 3, name: 'G3'), status: GameStatus.playing, addedAt: now.subtract(const Duration(days: 3)));
      final e4 = LibraryEntry(game: const Game(id: 4, name: 'G4'), status: GameStatus.playing, addedAt: now.subtract(const Duration(days: 2)));
      final e5 = LibraryEntry(game: const Game(id: 5, name: 'G5'), status: GameStatus.playing, addedAt: now);

      when(() => mockRepo.getLibraryGames()).thenAnswer((_) async => [e1, e2, e3, e4, e5]);

      final vm = LibraryViewModel(repo: mockRepo);
      await Future.delayed(Duration.zero);

      final recent = vm.recentEntries;
      expect(recent.length, 4);
      expect(recent[0].game.id, 5); // mais recente
      expect(recent[1].game.id, 2);
      expect(recent[2].game.id, 4);
      expect(recent[3].game.id, 3);
    });

    test('Deve recarregar a biblioteca ao atualizar o usuário autenticado', () async {
      when(() => mockRepo.getLibraryGames()).thenAnswer((_) async => [entry1]);

      final vm = LibraryViewModel(repo: mockRepo);
      await Future.delayed(Duration.zero);
      expect(vm.totalCount, 1);

      // Simula login posterior onde o repositório agora retorna entradas do usuário autenticado
      when(() => mockRepo.getLibraryGames()).thenAnswer((_) async => [entry1, entry2]);
      vm.updateCurrentUser('user-uuid-123', reload: true);
      await Future.delayed(Duration.zero);

      expect(vm.currentUserId, 'user-uuid-123');
      expect(vm.totalCount, 2);
    });
  });
}
