import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/game.dart';
import '../repositories/game_repository.dart';

class LibraryViewModel extends ChangeNotifier {
  final IGameRepository _repository;
  StreamSubscription? _subscription;

  List<LibraryEntry> _entries = [];
  GameStatus? _selectedFilter;
  String? _currentUserId;
  bool _isLoading = false;

  LibraryViewModel({required IGameRepository repo})
      : _repository = repo {
    _init();
  }

  List<LibraryEntry> get allEntries => List.unmodifiable(_entries);
  GameStatus? get selectedFilter => _selectedFilter;
  String? get currentUserId => _currentUserId;
  bool get isLoading => _isLoading;
  int get totalCount => _entries.length;

  /// Retorna até 4 jogos adicionados recentemente à biblioteca ordenados por data decrescente.
  List<LibraryEntry> get recentEntries {
    final list = List<LibraryEntry>.from(_entries);
    list.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return list.take(4).toList();
  }

  /// Retorna as entradas filtradas conforme o status selecionado.
  List<LibraryEntry> get filteredEntries {
    if (_selectedFilter != null) {
      return _entries.where((e) => e.status == _selectedFilter).toList();
    }
    return _entries;
  }

  int countForStatus(GameStatus status) {
    return _entries.where((e) => e.status == status).length;
  }

  void _init() {
    loadLibrary();
    _subscription = _repository.libraryChanges.listen((updatedEntries) {
      _entries = updatedEntries;
      notifyListeners();
    });
  }

  Future<void> loadLibrary() async {
    _isLoading = true;
    notifyListeners();

    try {
      _entries = await _repository.getLibraryGames();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setFilter(GameStatus? filter) {
    _selectedFilter = filter;
    notifyListeners();
  }

  void updateCurrentUser(String? userId, {bool reload = true}) {
    final changed = _currentUserId != userId;
    _currentUserId = userId;
    notifyListeners();
    if (changed && reload) {
      loadLibrary();
    }
  }

  Future<void> updateGameStatus(int gameId, GameStatus newStatus) async {
    await _repository.updateGameStatus(gameId, newStatus);
  }

  Future<void> removeGame(int gameId) async {
    await _repository.removeGame(gameId);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
