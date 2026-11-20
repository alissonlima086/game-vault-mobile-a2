import 'package:flutter/foundation.dart';
import '../models/game.dart';
import '../repositories/game_repository.dart';
import '../services/igdb_service.dart';

class GameDetailsViewModel extends ChangeNotifier {
  final Game game;
  final IGameRepository repository;
  final IIgdbService? igdbService;

  LibraryEntry? _entry;
  GameStatus _selectedStatus = GameStatus.wishlist;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _feedbackMessage;

  List<Game> _similarGames = [];
  bool _loadingSimilar = false;

  GameDetailsViewModel({
    required this.game,
    required IGameRepository repo,
    this.igdbService,
  })  : repository = repo {
    _loadStatus();
    _loadSimilarGames();
  }

  LibraryEntry? get entry => _entry;
  bool get isInLibrary => _entry != null;
  GameStatus get selectedStatus => _selectedStatus;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get feedbackMessage => _feedbackMessage;
  List<Game> get similarGames => _similarGames;
  bool get loadingSimilar => _loadingSimilar;

  Future<void> _loadStatus() async {
    _isLoading = true;
    notifyListeners();

    try {
      _entry = await repository.getGameById(game.id);
      if (_entry != null) {
        _selectedStatus = _entry!.status;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadSimilarGames() async {
    if (igdbService == null || game.similarGames.isEmpty) return;

    _loadingSimilar = true;
    notifyListeners();

    try {
      final results = await igdbService!.getGamesByIds(game.similarGames);
      _similarGames = results;
    } catch (e) {
      debugPrint('[GameDetailsViewModel] Erro ao carregar jogos recomendados: $e');
    } finally {
      _loadingSimilar = false;
      notifyListeners();
    }
  }

  void setSelectedStatus(GameStatus status) {
    _selectedStatus = status;
    notifyListeners();
  }

  /// Salva ou atualiza o status do jogo na biblioteca.
  Future<bool> saveToLibrary({String? notes, int? rating}) async {
    _isSaving = true;
    _feedbackMessage = null;
    notifyListeners();

    try {
      await repository.saveGame(
        game,
        _selectedStatus,
        notes: notes,
        userRating: rating,
      );
      _entry = await repository.getGameById(game.id);
      _feedbackMessage = '${game.name} foi adicionado à sua biblioteca como "${_selectedStatus.label}"!';
      return true;
    } catch (e) {
      _feedbackMessage = 'Erro ao salvar jogo na biblioteca.';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Remove o jogo da biblioteca.
  Future<bool> removeFromLibrary() async {
    if (!isInLibrary) return false;

    _isSaving = true;
    notifyListeners();

    try {
      await repository.removeGame(game.id);
      _entry = null;
      _feedbackMessage = '${game.name} foi removido da sua biblioteca.';
      return true;
    } catch (e) {
      _feedbackMessage = 'Erro ao remover jogo da biblioteca.';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
