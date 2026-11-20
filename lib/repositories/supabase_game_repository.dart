import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/game.dart';
import 'game_repository.dart';

/// Implementação do repositório de jogos com persistência em nuvem via Supabase PostgreSQL
class SupabaseGameRepository implements IGameRepository {
  final SupabaseClient? _supabaseClient;
  final InMemoryGameRepository _localFallback;
  final StreamController<List<LibraryEntry>> _changeController =
      StreamController<List<LibraryEntry>>.broadcast();

  RealtimeChannel? _realtimeChannel;
  StreamSubscription? _localSubscription;
  StreamSubscription? _authSubscription;

  SupabaseGameRepository({
    SupabaseClient? client,
    InMemoryGameRepository? localFallback,
  })  : _supabaseClient = client,
        _localFallback = localFallback ?? InMemoryGameRepository() {
    _init();
  }

  SupabaseClient? get _client {
    if (_supabaseClient != null) return _supabaseClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  void _init() {
    // Sincroniza notificações locais do fallback para a stream unificada
    _localSubscription = _localFallback.libraryChanges.listen((entries) {
      if (_client?.auth.currentUser == null) {
        _changeController.add(entries);
      }
    });

    // Reage automaticamente quando a sessão é restaurada ou alterada
    final client = _client;
    if (client != null) {
      try {
        _authSubscription = client.auth.onAuthStateChange.listen((data) async {
          final session = data.session;
          debugPrint('[SupabaseGameRepository] Sessão de autenticação atualizada (${data.event}).');
          if (session != null) {
            final games = await getLibraryGames();
            _changeController.add(games);
          }
        });
      } catch (e) {
        debugPrint('[SupabaseGameRepository] Erro ao assinar onAuthStateChange: $e');
      }
    }

    _setupRealtimeSubscription();
  }

  void _setupRealtimeSubscription() {
    final client = _client;
    if (client == null) return;

    try {
      _realtimeChannel = client
          .channel('public:library_entries')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'library_entries',
            callback: (payload) async {
              debugPrint('[SupabaseGameRepository] Mudança remota detectada via Realtime: ${payload.eventType}');
              final games = await getLibraryGames();
              _changeController.add(games);
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('[SupabaseGameRepository] Não foi possível assinar canal Realtime: $e');
    }
  }

  @override
  Stream<List<LibraryEntry>> get libraryChanges => _changeController.stream;

  @override
  Future<List<LibraryEntry>> getLibraryGames() async {
    final client = _client;
    final currentUser = client?.auth.currentUser;

    if (client != null && currentUser != null) {
      try {
        final List<dynamic> response = await client
            .from('library_entries')
            .select('*, game:games(*)')
            .eq('user_id', currentUser.id)
            .order('created_at', ascending: false);

        final entries = response
            .whereType<Map<String, dynamic>>()
            .map(LibraryEntry.fromSupabaseJson)
            .toList();

        return entries;
      } on PostgrestException catch (e) {
        debugPrint(
          '[SupabaseGameRepository] Consulta ao banco falhou: ${e.message} '
          '(Código: ${e.code}). Utilizando armazenamento local.',
        );
      } catch (e) {
        debugPrint('[SupabaseGameRepository] Erro ao carregar da nuvem: $e');
      }
    }

    return _localFallback.getLibraryGames();
  }

  @override
  Future<LibraryEntry?> getGameById(int gameId) async {
    final client = _client;
    final currentUser = client?.auth.currentUser;

    if (client != null && currentUser != null) {
      try {
        final response = await client
            .from('library_entries')
            .select('*, game:games(*)')
            .eq('user_id', currentUser.id)
            .eq('game_id', gameId)
            .maybeSingle();

        if (response != null) {
          return LibraryEntry.fromSupabaseJson(response);
        }
      } catch (e) {
        debugPrint('[SupabaseGameRepository] Erro ao buscar jogo $gameId na nuvem: $e');
      }
    }

    return _localFallback.getGameById(gameId);
  }

  @override
  Future<void> saveGame(
    Game game,
    GameStatus status, {
    String? notes,
    int? userRating,
  }) async {
    final client = _client;
    final currentUser = client?.auth.currentUser;

    if (client != null && currentUser != null) {
      try {
        // 1. Salva/atualiza o catálogo de jogos compartilhado na tabela 'games'
        await client.from('games').upsert(
          game.toGamesTableJson(),
          onConflict: 'id',
        );

        // 2. Salva a entrada na biblioteca pessoal do usuário
        final payload = {
          'user_id': currentUser.id,
          'game_id': game.id,
          'status': status.name,
          'notes': notes,
          'user_rating': userRating,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        };

        await client
            .from('library_entries')
            .upsert(payload, onConflict: 'user_id,game_id');

        debugPrint('[SupabaseGameRepository] Jogo ${game.name} sincronizado na nuvem com sucesso.');

        final updatedList = await getLibraryGames();
        _changeController.add(updatedList);
        return;
      } on PostgrestException catch (e) {
        debugPrint(
          '[SupabaseGameRepository] Erro de persistência no Supabase: ${e.message} '
          '(Código: ${e.code}). Salvando localmente como fallback.',
        );
      } catch (e) {
        debugPrint('[SupabaseGameRepository] Erro na requisição Supabase: $e');
      }
    }

    // Fallback local se não estiver logado ou em caso de falha de conexão/tabela inexistente
    await _localFallback.saveGame(
      game,
      status,
      notes: notes,
      userRating: userRating,
    );
    final fallbackList = await _localFallback.getLibraryGames();
    _changeController.add(fallbackList);
  }

  @override
  Future<void> updateGameStatus(int gameId, GameStatus status) async {
    final client = _client;
    final currentUser = client?.auth.currentUser;

    if (client != null && currentUser != null) {
      try {
        await client
            .from('library_entries')
            .update({
              'status': status.name,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('game_id', gameId)
            .eq('user_id', currentUser.id);

        final updatedList = await getLibraryGames();
        _changeController.add(updatedList);
        return;
      } catch (e) {
        debugPrint('[SupabaseGameRepository] Erro ao atualizar status na nuvem: $e');
      }
    }

    await _localFallback.updateGameStatus(gameId, status);
    final fallbackList = await _localFallback.getLibraryGames();
    _changeController.add(fallbackList);
  }

  @override
  Future<void> removeGame(int gameId) async {
    final client = _client;
    final currentUser = client?.auth.currentUser;

    if (client != null && currentUser != null) {
      try {
        await client
            .from('library_entries')
            .delete()
            .eq('game_id', gameId)
            .eq('user_id', currentUser.id);

        final updatedList = await getLibraryGames();
        _changeController.add(updatedList);
        return;
      } catch (e) {
        debugPrint('[SupabaseGameRepository] Erro ao remover da nuvem: $e');
      }
    }

    await _localFallback.removeGame(gameId);
    final fallbackList = await _localFallback.getLibraryGames();
    _changeController.add(fallbackList);
  }

  @override
  Future<bool> isGameInLibrary(int gameId) async {
    final entry = await getGameById(gameId);
    return entry != null;
  }

  void dispose() {
    _realtimeChannel?.unsubscribe();
    _authSubscription?.cancel();
    _localSubscription?.cancel();
    _changeController.close();
  }
}
