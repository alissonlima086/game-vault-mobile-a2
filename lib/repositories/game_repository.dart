import 'dart:async';
import '../models/game.dart';

/// Persistência da biblioteca de jogos (local)
abstract class IGameRepository {
  /// Lista todas as entradas na biblioteca
  Future<List<LibraryEntry>> getLibraryGames();

  /// Busca um jogo específico pelo ID 
  Future<LibraryEntry?> getGameById(int gameId);

  /// Salva ou atualiza um jogo na biblioteca
  Future<void> saveGame(
    Game game,
    GameStatus status, {
    String? notes,
    int? userRating,
  });

  /// Atualiza apenas o status de um jogo já na biblioteca
  Future<void> updateGameStatus(int gameId, GameStatus status);

  /// Remove o jogo da biblioteca
  Future<void> removeGame(int gameId);

  /// Verifica se o jogo está na biblioteca
  Future<bool> isGameInLibrary(int gameId);

  /// Notificação mudança
  Stream<List<LibraryEntry>> get libraryChanges;
}

/// Implementação em memória do repositório
class InMemoryGameRepository implements IGameRepository {
  final Map<int, LibraryEntry> _entries = {};
  final StreamController<List<LibraryEntry>> _controller =
      StreamController<List<LibraryEntry>>.broadcast();

  InMemoryGameRepository([List<LibraryEntry>? initialEntries]) {
    if (initialEntries != null) {
      for (final entry in initialEntries) {
        _entries[entry.game.id] = entry;
      }
    }
  }

  @override
  Stream<List<LibraryEntry>> get libraryChanges => _controller.stream;

  @override
  Future<List<LibraryEntry>> getLibraryGames() async {
    return _entries.values.toList()
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
  }

  @override
  Future<LibraryEntry?> getGameById(int gameId) async {
    return _entries[gameId];
  }

  @override
  Future<void> saveGame(
    Game game,
    GameStatus status, {
    String? notes,
    int? userRating,
  }) async {
    final now = DateTime.now();
    final existing = _entries[game.id];

    _entries[game.id] = LibraryEntry(
      game: game,
      status: status,
      addedAt: existing?.addedAt ?? now,
      notes: notes ?? existing?.notes,
      userRating: userRating ?? existing?.userRating,
    );

    _controller.add(_entries.values.toList());
  }

  @override
  Future<void> updateGameStatus(int gameId, GameStatus status) async {
    final entry = _entries[gameId];
    if (entry != null) {
      _entries[gameId] = entry.copyWith(status: status);
      _controller.add(_entries.values.toList());
    }
  }

  @override
  Future<void> removeGame(int gameId) async {
    if (_entries.remove(gameId) != null) {
      _controller.add(_entries.values.toList());
    }
  }

  @override
  Future<bool> isGameInLibrary(int gameId) async {
    return _entries.containsKey(gameId);
  }

  void dispose() {
    _controller.close();
  }
}
