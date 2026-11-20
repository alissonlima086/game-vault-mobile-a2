import 'package:flutter/foundation.dart';
import '../models/game.dart';
import '../services/igdb_service.dart';

/// Estados possíveis da tela de pesquisa conforme RF da entrega.
enum SearchState {
  initial,
  loading,
  success,
  empty,
  error,
}

class SearchViewModel extends ChangeNotifier {
  final IIgdbService _igdbService;

  SearchState _state = SearchState.initial;
  List<Game> _results = [];
  String? _errorMessage;
  String _currentQuery = '';

  SearchViewModel({required IIgdbService service})
      : _igdbService = service;

  SearchState get state => _state;
  List<Game> get results => List.unmodifiable(_results);
  String? get errorMessage => _errorMessage;
  String get currentQuery => _currentQuery;
  bool get isLoading => _state == SearchState.loading;
  bool get hasResults => _state == SearchState.success && _results.isNotEmpty;
  bool get isFallbackMode => _igdbService.isFallbackMode == true;

  /// Validador síncrono para o campo de formulário.
  String? validateQuery(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Por favor, digite o nome de um jogo.';
    }
    if (value.trim().length < 2) {
      return 'O termo de pesquisa deve ter pelo menos 2 caracteres.';
    }
    if (value.trim().length > 100) {
      return 'O termo de pesquisa é muito longo (máximo 100 caracteres).';
    }
    return null;
  }

  /// Executa a busca na IGDB através do serviço.
  Future<void> search(String query) async {
    final validation = validateQuery(query);
    if (validation != null) {
      _errorMessage = validation;
      _state = SearchState.error;
      notifyListeners();
      return;
    }

    final trimmed = query.trim();
    _currentQuery = trimmed;
    _state = SearchState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final games = await _igdbService.searchGames(trimmed);
      _results = games;
      if (games.isEmpty) {
        _state = SearchState.empty;
      } else {
        _state = SearchState.success;
      }
    } on IgdbException catch (e) {
      _errorMessage = e.message;
      _state = SearchState.error;
    } catch (e) {
      _errorMessage = 'Ocorreu um erro inesperado ao pesquisar jogos.';
      _state = SearchState.error;
    } finally {
      notifyListeners();
    }
  }

  /// Limpa a pesquisa e retorna ao estado inicial.
  void clear() {
    _state = SearchState.initial;
    _results = [];
    _errorMessage = null;
    _currentQuery = '';
    notifyListeners();
  }
}
