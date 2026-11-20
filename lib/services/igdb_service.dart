import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/game.dart';

/// Exception para erros de consulta
class IgdbException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic originalError;

  const IgdbException(this.message, {this.statusCode, this.originalError});

  @override
  String toString() => message;
}

/// Interface para o IGDB
abstract class IIgdbService {
  Future<List<Game>> searchGames(String query, {int limit = 20});
  Future<List<Game>> getGamesByIds(List<int> ids);
  bool get isFallbackMode => false;
}

/// IGDB via Supabase Edge Function (`igdb-proxy`).
class IgdbService implements IIgdbService {
  final SupabaseClient? _supabaseClient;
  final bool enableFallbackOn404;
  bool _isFallbackMode = false;

  IgdbService({
    SupabaseClient? client,
    this.enableFallbackOn404 = true,
  }) : _supabaseClient = client;

  @override
  bool get isFallbackMode => _isFallbackMode;

  SupabaseClient? get _client {
    if (_supabaseClient != null) return _supabaseClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Game>> searchGames(String query, {int limit = 20}) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.length < 2) {
      throw const IgdbException('O termo de pesquisa deve ter pelo menos 2 caracteres.');
    }

    final client = _client;

    // Chamar a Edge Function se o cliente Supabase estiver disponível
    if (client != null) {
      try {
        final FunctionResponse response = await client.functions
            .invoke(
              'igdb-proxy',
              body: {
                'query': trimmedQuery,
                'limit': limit,
              },
            )
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () => throw const IgdbException(
                'Tempo limite esgotado ao consultar a IGDB. Verifique sua conexão.',
                statusCode: 408,
              ),
            );

        if (response.status == 200 && response.data != null) {
          _isFallbackMode = false;
          final data = response.data;
          List rawGames = [];
          if (data is Map && data['games'] is List) {
            rawGames = data['games'] as List;
          } else if (data is List) {
            rawGames = data;
          }

          return rawGames
              .whereType<Map<String, dynamic>>()
              .map(Game.fromJson)
              .toList();
        }

        // Se a função retornar erro de validação
        if (response.status == 400) {
          final msg = (response.data is Map && response.data['error'] != null)
              ? response.data['error'].toString()
              : 'Parâmetro de busca inválido.';
          throw IgdbException(msg, statusCode: 400);
        }

        // Se retornar 404 (Edge Function ainda sem deploy no Supabase)
        if (response.status == 404 && enableFallbackOn404) {
          _isFallbackMode = true;
          debugPrint(
            '[IgdbService] Edge function igdb-proxy retornou 404 (sem deploy). '
            'Utilizando dados demonstrativos reais da IGDB para teste local.',
          );
          return _filterCuratedMockGames(trimmedQuery);
        }

        throw IgdbException(
          'Falha na resposta do servidor (HTTP ${response.status}).',
          statusCode: response.status,
        );
      } on FunctionException catch (e) {
        final isNotDeployedOrNetwork = e.status == 404 ||
            e.details?.toString().contains('NetworkError') == true ||
            e.details?.toString().contains('NOT_FOUND') == true ||
            e.reasonPhrase?.toString().contains('NOT_FOUND') == true;

        if (isNotDeployedOrNetwork && enableFallbackOn404) {
          _isFallbackMode = true;
          debugPrint(
            '[IgdbService] Edge Function igdb-proxy ainda sem deploy no Supabase (${e.details ?? e.status}). '
            'Utilizando catálogo demonstrativo da IGDB.',
          );
          return _filterCuratedMockGames(trimmedQuery);
        }
        throw IgdbException(
          'Erro na Edge Function: ${e.details ?? e.reasonPhrase ?? e.status}',
          statusCode: e.status,
          originalError: e,
        );
      } on IgdbException {
        rethrow;
      } catch (e) {
        if (enableFallbackOn404) {
          _isFallbackMode = true;
          debugPrint('[IgdbService] Erro ao invocar Edge Function: $e. Utilizando fallback local.');
          return _filterCuratedMockGames(trimmedQuery);
        }
        throw IgdbException(
          'Falha na comunicação com o serviço: $e',
          originalError: e,
        );
      }
    }

    // Se o cliente não foi inicializado / sem env
    if (enableFallbackOn404) {
      _isFallbackMode = true;
      return _filterCuratedMockGames(trimmedQuery);
    }

    throw const IgdbException(
      'Cliente Supabase não inicializado. Configure o arquivo .env com SUPABASE_URL e SUPABASE_PUBLISHABLE_KEY.',
    );
  }

  @override
  Future<List<Game>> getGamesByIds(List<int> ids) async {
    if (ids.isEmpty) return [];

    final client = _client;
    if (client != null) {
      try {
        final FunctionResponse response = await client.functions
            .invoke(
              'igdb-proxy',
              body: {'ids': ids},
            )
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () => throw const IgdbException(
                'Tempo limite esgotado ao buscar recomendações da IGDB.',
                statusCode: 408,
              ),
            );

        if (response.status == 200 && response.data != null) {
          _isFallbackMode = false;
          final data = response.data;
          List rawGames = [];
          if (data is Map && data['games'] is List) {
            rawGames = data['games'] as List;
          } else if (data is List) {
            rawGames = data;
          }

          return rawGames
              .whereType<Map<String, dynamic>>()
              .map(Game.fromJson)
              .toList();
        }

        if (response.status == 404 && enableFallbackOn404) {
          _isFallbackMode = true;
          return _findGamesByIdsFromMock(ids);
        }

        throw IgdbException(
          'Falha ao carregar jogos recomendados (HTTP ${response.status}).',
          statusCode: response.status,
        );
      } on FunctionException catch (e) {
        final isNotDeployedOrNetwork = e.status == 404 ||
            e.details?.toString().contains('NetworkError') == true ||
            e.details?.toString().contains('NOT_FOUND') == true ||
            e.reasonPhrase?.toString().contains('NOT_FOUND') == true;

        if (isNotDeployedOrNetwork && enableFallbackOn404) {
          _isFallbackMode = true;
          return _findGamesByIdsFromMock(ids);
        }
        throw IgdbException(
          'Erro ao consultar recomendações: ${e.details ?? e.reasonPhrase ?? e.status}',
          statusCode: e.status,
          originalError: e,
        );
      } catch (e) {
        if (enableFallbackOn404) {
          _isFallbackMode = true;
          return _findGamesByIdsFromMock(ids);
        }
        throw IgdbException(
          'Erro ao consultar recomendações: $e',
          originalError: e,
        );
      }
    }

    if (enableFallbackOn404) {
      _isFallbackMode = true;
      return _findGamesByIdsFromMock(ids);
    }

    return [];
  }

  List<Game> _findGamesByIdsFromMock(List<int> ids) {
    final found = _curatedRealGames.where((g) => ids.contains(g.id)).toList();
    if (found.isNotEmpty) return found;

    return ids.take(4).map((id) {
      return Game(
        id: id,
        name: 'Jogo Recomendado #$id',
        summary: 'Jogo semelhante sugerido pela IGDB.',
        coverUrl: 'https://images.igdb.com/igdb/image/upload/t_cover_big/co1wyy.jpg',
        genres: const ['Ação', 'Aventura'],
        rating: 85.0,
      );
    }).toList();
  }

  static String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[áàãâä]'), 'a')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[íìîï]'), 'i')
        .replaceAll(RegExp(r'[óòõôö]'), 'o')
        .replaceAll(RegExp(r'[úùûü]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Catálogo curado representativo para testes offline e garantia de funcionamento.
  /// Pesquisa com prioridade em nome do jogo para evitar resultados inesperados.
  List<Game> _filterCuratedMockGames(String query) {
    final normalizedQuery = _normalize(query);
    if (normalizedQuery.isEmpty) return [];

    final queryWords = normalizedQuery.split(' ').where((w) => w.isNotEmpty).toList();

    // 1. Busca prioritária por correspondência de título (exato ou parcial)
    final byName = _curatedRealGames.where((g) {
      final normName = _normalize(g.name);
      if (normName.contains(normalizedQuery)) return true;
      if (queryWords.length > 1 && queryWords.every((word) => normName.contains(word))) {
        return true;
      }
      return false;
    }).toList();

    if (byName.isNotEmpty) {
      return byName;
    }

    // 2. Busca secundária por correspondência de gênero
    final byGenre = _curatedRealGames.where((g) {
      return g.genres.any((genre) {
        final normGenre = _normalize(genre);
        return normGenre.contains(normalizedQuery) ||
            (queryWords.length > 1 && queryWords.every((w) => normGenre.contains(w)));
      });
    }).toList();

    if (byGenre.isNotEmpty) {
      return byGenre;
    }

    // 3. Somente se não houver jogo com o título ou gênero buscado, pesquisa em sinopse
    return _curatedRealGames.where((g) {
      final normSummary = _normalize(g.summary ?? '');
      return normSummary.contains(normalizedQuery);
    }).toList();
  }

  static final List<Game> _curatedRealGames = [
    // 1. Super Mario Odyssey
    const Game(
      id: 26758,
      name: 'Super Mario Odyssey',
      summary:
          'Join Mario on a massive, globe-trotting 3D adventure and use his incredible new abilities to collect Moons so you can power up your airship, the Odyssey, and rescue Princess Peach from Bowser\'s wedding plans.',
      storyline: 'Bowser has once again kidnapped Princess Peach, but this time he is planning an elaborate wedding!',
      coverUrl: 'https://images.igdb.com/igdb/image/upload/t_cover_big/co1p98.jpg',
      genres: ['Platform', 'Adventure'],
      firstReleaseDate: null,
      rating: 97.0,
      platforms: ['Nintendo Switch'],
      similarGames: [1070, 7346, 119388],
    ),
    // 2. Super Mario World
    const Game(
      id: 1070,
      name: 'Super Mario World',
      summary:
          'During a vacation in Dinosaur Land, Princess Toadstool is kidnapped and Yoshi\'s eggs are trapped in magical eggs by Bowser and his Koopalings.',
      coverUrl: 'https://images.igdb.com/igdb/image/upload/t_cover_big/co649x.jpg',
      genres: ['Platform', 'Adventure'],
      firstReleaseDate: null,
      rating: 95.0,
      platforms: ['Super Nintendo Entertainment System (SNES)', 'Game Boy Advance'],
      similarGames: [26758, 121],
    ),
    // 3. The Legend of Zelda: Breath of the Wild
    const Game(
      id: 7346,
      name: 'The Legend of Zelda: Breath of the Wild',
      summary:
          'Step into a world of discovery, exploration and adventure in The Legend of Zelda: Breath of the Wild, a boundary-breaking new game in the acclaimed series.',
      storyline: 'Link awakens from a hundred-year slumber to defeat Calamity Ganon before it can destroy the kingdom of Hyrule.',
      coverUrl: 'https://images.igdb.com/igdb/image/upload/t_cover_big/co3p2d.jpg',
      genres: ['Role-playing (RPG)', 'Adventure'],
      firstReleaseDate: null,
      rating: 97.2,
      platforms: ['Nintendo Switch', 'Wii U'],
      similarGames: [119388, 119171, 1942],
    ),
    // 4. The Legend of Zelda: Tears of the Kingdom
    const Game(
      id: 119388,
      name: 'The Legend of Zelda: Tears of the Kingdom',
      summary:
          'An epic adventure across the land and skies of Hyrule awaits in The Legend of Zelda: Tears of the Kingdom. Create your own adventure in this open-world journey.',
      coverUrl: 'https://images.igdb.com/igdb/image/upload/t_cover_big/co5vmg.jpg',
      genres: ['Role-playing (RPG)', 'Adventure'],
      firstReleaseDate: null,
      rating: 96.0,
      platforms: ['Nintendo Switch'],
      similarGames: [7346, 119171],
    ),
    // 5. Minecraft
    const Game(
      id: 121,
      name: 'Minecraft',
      summary:
          'Minecraft focuses on allowing the player to explore, interact with, and modify a dynamically-generated map made of one-cubic-meter-sized blocks. The environment includes plants, mobs, and items.',
      coverUrl: 'https://images.igdb.com/igdb/image/upload/t_cover_big/co49x5.jpg',
      genres: ['Adventure', 'Simulator', 'Indie'],
      firstReleaseDate: null,
      rating: 93.0,
      platforms: ['PC (Microsoft Windows)', 'PlayStation 4', 'Xbox One', 'Nintendo Switch', 'Android', 'iOS'],
      similarGames: [17000, 26845],
    ),
    // 6. God of War (2018)
    const Game(
      id: 19560,
      name: 'God of War',
      summary:
          'His vengeance against the Gods of Olympus years behind him, Kratos now lives as a man in the realm of Norse Gods and monsters. It is in this harsh, unforgiving world that he must fight to survive... and teach his son to do the same.',
      coverUrl: 'https://images.igdb.com/igdb/image/upload/t_cover_big/co1tmu.jpg',
      genres: ['Action', 'Adventure', 'Hack and slash/Beat \'em up'],
      firstReleaseDate: null,
      rating: 95.5,
      platforms: ['PlayStation 4', 'PC (Microsoft Windows)'],
      similarGames: [119277, 119171, 1942],
    ),
    // 7. God of War Ragnarök
    const Game(
      id: 119277,
      name: 'God of War Ragnarök',
      summary:
          'Kratos and Atreus embark on an epic and heartfelt journey as they struggle with holding on and letting go against the encroaching winds of Fimbulwinter.',
      coverUrl: 'https://images.igdb.com/igdb/image/upload/t_cover_big/co5s5v.jpg',
      genres: ['Action', 'Adventure', 'Hack and slash/Beat \'em up'],
      firstReleaseDate: null,
      rating: 94.0,
      platforms: ['PlayStation 4', 'PlayStation 5', 'PC (Microsoft Windows)'],
      similarGames: [19560, 119171],
    ),
    // 8. Red Dead Redemption 2
    const Game(
      id: 25076,
      name: 'Red Dead Redemption 2',
      summary:
          'America, 1899. The end of the wild west era has begun. Arthur Morgan and the Van der Linde gang are outlaws on the run across the vast and rugged American heartland.',
      coverUrl: 'https://images.igdb.com/igdb/image/upload/t_cover_big/co1q1f.jpg',
      genres: ['Shooter', 'Role-playing (RPG)', 'Adventure'],
      firstReleaseDate: null,
      rating: 96.5,
      platforms: ['PlayStation 4', 'Xbox One', 'PC (Microsoft Windows)'],
      similarGames: [1020, 1942, 434],
    ),
    // 9. Grand Theft Auto V
    const Game(
      id: 1020,
      name: 'Grand Theft Auto V',
      summary:
          'When a young street hustler, a retired bank robber and a terrifying psychopath find themselves entangled with some of the most frightening and deranged elements of the criminal underworld.',
      coverUrl: 'https://images.igdb.com/igdb/image/upload/t_cover_big/co2lbd.jpg',
      genres: ['Shooter', 'Adventure'],
      firstReleaseDate: null,
      rating: 93.5,
      platforms: ['PC (Microsoft Windows)', 'PlayStation 4', 'Xbox One', 'PlayStation 5', 'Xbox Series X|S'],
      similarGames: [434, 25076, 1877],
    ),
    // 10. Grand Theft Auto: San Andreas
    const Game(
      id: 434,
      name: 'Grand Theft Auto: San Andreas',
      summary:
          'Five years ago Carl Johnson escaped from the pressures of life in Los Santos, San Andreas... a city tearing itself apart with gang trouble, drugs and corruption.',
      coverUrl: 'https://images.igdb.com/igdb/image/upload/t_cover_big/co20au.jpg',
      genres: ['Shooter', 'Adventure'],
      firstReleaseDate: null,
      rating: 92.0,
      platforms: ['PlayStation 2', 'PC (Microsoft Windows)', 'Xbox', 'Android', 'iOS'],
      similarGames: [1020, 25076],
    ),
    // 11. The Witcher 3: Wild Hunt
    const Game(
      id: 1942,
      name: 'The Witcher 3: Wild Hunt',
      summary:
          'The Witcher 3: Wild Hunt is a story-driven, next-generation open world role-playing game set in a visually stunning fantasy universe full of meaningful choices and impactful consequences.',
      storyline:
          'Geralt of Rivia, a monster slayer for hire, embarks on a journey to find the child of prophecy in a vast world rich with merchant cities, pirate islands, and perilous mountain passes.',
      coverUrl: 'https://images.igdb.com/igdb/image/upload/t_cover_big/co1wyy.jpg',
      genres: ['Role-playing (RPG)', 'Adventure'],
      firstReleaseDate: null,
      rating: 95.8,
      platforms: ['PC (Microsoft Windows)', 'PlayStation 4', 'Xbox One', 'Nintendo Switch', 'PlayStation 5', 'Xbox Series X|S'],
      similarGames: [119171, 1877, 472],
    ),
    // 12. Elden Ring
    const Game(
      id: 119171,
      name: 'Elden Ring',
      summary:
          'A vast world where open fields with a variety of situations and huge dungeons with complex and three-dimensional designs are seamlessly connected. Unravel the mystery of the Elden Ring.',
      coverUrl: 'https://images.igdb.com/igdb/image/upload/t_cover_big/co4jni.jpg',
      genres: ['Role-playing (RPG)', 'Adventure'],
      firstReleaseDate: null,
      rating: 95.1,
      platforms: ['PC (Microsoft Windows)', 'PlayStation 4', 'Xbox One', 'PlayStation 5', 'Xbox Series X|S'],
      similarGames: [1942, 11133, 7334],
    ),
    // 13. Dark Souls III
    const Game(
      id: 11133,
      name: 'Dark Souls III',
      summary:
          'As fires fade and the world falls into ruin, developer FromSoftware continues their critically acclaimed franchise with Dark Souls III. Atmospheric lighting and particle effects immerse players into a fantastical world.',
      coverUrl: 'https://images.igdb.com/igdb/image/upload/t_cover_big/co1x77.jpg',
      genres: ['Role-playing (RPG)', 'Adventure'],
      firstReleaseDate: null,
      rating: 92.5,
      platforms: ['PC (Microsoft Windows)', 'PlayStation 4', 'Xbox One'],
      similarGames: [119171, 7334, 103020],
    ),
    // 14. Bloodborne
    const Game(
      id: 7334,
      name: 'Bloodborne',
      summary:
          'Face your fears as you search for answers in the ancient city of Yharnam, now cursed with a strange endemic illness spreading through the streets like wildfire.',
      coverUrl: 'https://images.igdb.com/igdb/image/upload/t_cover_big/co1rbn.jpg',
      genres: ['Role-playing (RPG)', 'Hack and slash/Beat \'em up'],
      firstReleaseDate: null,
      rating: 93.0,
      platforms: ['PlayStation 4'],
      similarGames: [11133, 119171, 103020],
    ),
    // 15. Sekiro: Shadows Die Twice
    const Game(
      id: 103020,
      name: 'Sekiro: Shadows Die Twice',
      summary:
          'In Sekiro: Shadows Die Twice you are the "one-armed wolf", a disgraced and disfigured warrior rescued from the brink of death. Bound to protect a young lord, you become the target of vicious enemies.',
      coverUrl: 'https://images.igdb.com/igdb/image/upload/t_cover_big/co1v2f.jpg',
      genres: ['Adventure', 'Hack and slash/Beat \'em up'],
      firstReleaseDate: null,
      rating: 92.8,
      platforms: ['PC (Microsoft Windows)', 'PlayStation 4', 'Xbox One'],
      similarGames: [119171, 11133, 7334],
    ),
    // 16. The Elder Scrolls V: Skyrim
    const Game(
      id: 472,
      name: 'The Elder Scrolls V: Skyrim',
      summary:
          'The next chapter in the highly anticipated Elder Scrolls saga arrives from the makers of the 2006 and 2008 Games of the Year, Bethesda Game Studios. Skyrim reimagines and revolutionizes the open-world fantasy epic.',
      coverUrl: 'https://images.igdb.com/igdb/image/upload/t_cover_big/co1tnw.jpg',
      genres: ['Role-playing (RPG)', 'Adventure'],
      firstReleaseDate: null,
      rating: 93.0,
      platforms: ['PC (Microsoft Windows)', 'PlayStation 4', 'Xbox One', 'Nintendo Switch'],
      similarGames: [1942, 119171, 119133],
    ),
    // 17. Baldur\'s Gate 3
    const Game(
      id: 119133,
      name: 'Baldur\'s Gate 3',
      summary:
          'An ancient evil has returned to Baldur\'s Gate, intent on devouring it from the inside out. The fate of Faerûn lies in your hands. Gather your party and return to the Forgotten Realms.',
      coverUrl: 'https://images.igdb.com/igdb/image/upload/t_cover_big/co670h.jpg',
      genres: ['Role-playing (RPG)', 'Tactical', 'Turn-based strategy (TBS)'],
      firstReleaseDate: null,
      rating: 96.0,
      platforms: ['PC (Microsoft Windows)', 'PlayStation 5', 'Xbox Series X|S', 'Mac'],
      similarGames: [1942, 472],
    ),
    // 18. Pokémon Scarlet
    const Game(
      id: 191692,
      name: 'Pokémon Scarlet',
      summary:
          'The Pokémon Scarlet and Pokémon Violet games, the newest chapters in the Pokémon series, allow you to experience an open-world adventure where various towns blend seamlessly into the wilderness.',
      coverUrl: 'https://images.igdb.com/igdb/image/upload/t_cover_big/co5pck.jpg',
      genres: ['Role-playing (RPG)', 'Adventure'],
      firstReleaseDate: null,
      rating: 81.0,
      platforms: ['Nintendo Switch'],
      similarGames: [1511, 26758, 7346],
    ),
    // 19. Pokémon FireRed
    const Game(
      id: 1511,
      name: 'Pokémon FireRed Version',
      summary:
          'Return to the Kanto region in this Game Boy Advance remake of the classic Pokémon Red. Catch, train, and battle Pokémon on your quest to become the Pokémon Champion.',
      coverUrl: 'https://images.igdb.com/igdb/image/upload/t_cover_big/co1xce.jpg',
      genres: ['Role-playing (RPG)', 'Adventure'],
      firstReleaseDate: null,
      rating: 89.0,
      platforms: ['Game Boy Advance'],
      similarGames: [191692, 1070],
    ),
    // 20. Hollow Knight
    const Game(
      id: 9767,
      name: 'Hollow Knight',
      summary:
          'Forge your own path in Hollow Knight! An epic action adventure through a vast ruined kingdom of insects and heroes. Explore twisting caverns and battle tainted creatures.',
      coverUrl: 'https://images.igdb.com/igdb/image/upload/t_cover_big/co9576.jpg',
      genres: ['Platform', 'Adventure', 'Indie'],
      firstReleaseDate: null,
      rating: 91.0,
      platforms: ['PC (Microsoft Windows)', 'Mac', 'Linux', 'Nintendo Switch', 'PlayStation 4', 'Xbox One'],
      similarGames: [114283, 26845],
    ),
    // 21. Hades
    const Game(
      id: 114283,
      name: 'Hades',
      summary:
          'Defy the god of the dead as you hack and slash out of the Underworld in this rogue-like dungeon crawler from the creators of Bastion, Transistor, and Pyre.',
      coverUrl: 'https://images.igdb.com/igdb/image/upload/t_cover_big/co1r7f.jpg',
      genres: ['Role-playing (RPG)', 'Hack and slash/Beat \'em up', 'Indie'],
      firstReleaseDate: null,
      rating: 92.4,
      platforms: ['PC (Microsoft Windows)', 'Mac', 'Nintendo Switch', 'PlayStation 4', 'PlayStation 5', 'Xbox One', 'Xbox Series X|S'],
      similarGames: [9767, 1942],
    ),
    // 22. Celeste
    const Game(
      id: 26845,
      name: 'Celeste',
      summary:
          'Help Madeline survive her inner demons on her journey to the top of Celeste Mountain, in this super-tight platformer from the creators of TowerFall. Brave hundreds of hand-crafted challenges.',
      coverUrl: 'https://images.igdb.com/igdb/image/upload/t_cover_big/co213w.jpg',
      genres: ['Platform', 'Adventure', 'Indie'],
      firstReleaseDate: null,
      rating: 92.0,
      platforms: ['PC (Microsoft Windows)', 'Nintendo Switch', 'PlayStation 4', 'Xbox One'],
      similarGames: [9767, 17000],
    ),
    // 23. Stardew Valley
    const Game(
      id: 17000,
      name: 'Stardew Valley',
      summary:
          'You\'ve inherited your grandfather\'s old farm plot in Stardew Valley. Armed with hand-me-down tools and a few coins, you set out to begin your new life!',
      coverUrl: 'https://images.igdb.com/igdb/image/upload/t_cover_big/co1m9h.jpg',
      genres: ['Role-playing (RPG)', 'Simulator', 'Indie'],
      firstReleaseDate: null,
      rating: 92.5,
      platforms: ['PC (Microsoft Windows)', 'Nintendo Switch', 'PlayStation 4', 'Xbox One', 'Android', 'iOS'],
      similarGames: [121, 26845],
    ),
    // 24. Cyberpunk 2077
    const Game(
      id: 1877,
      name: 'Cyberpunk 2077',
      summary:
          'Cyberpunk 2077 is an open-world, action-adventure RPG set in the megalopolis of Night City, where you play as a cyberpunk mercenary wrapped up in a do-or-die fight for survival.',
      coverUrl: 'https://images.igdb.com/igdb/image/upload/t_cover_big/co7088.jpg',
      genres: ['Role-playing (RPG)', 'Shooter', 'Adventure'],
      firstReleaseDate: null,
      rating: 81.5,
      platforms: ['PC (Microsoft Windows)', 'PlayStation 4', 'Xbox One', 'PlayStation 5', 'Xbox Series X|S'],
      similarGames: [1942, 119171, 1020],
    ),
    // 25. Warframe
    const Game(
      id: 265,
      name: 'Warframe',
      summary:
          'Warframe is a cooperative free-to-play third person online action shooter set in an evolving sci-fi world. Join your friends in player-vs-enemy raids across the solar system.',
      storyline:
          'In Warframe, players control members of the Tenno, a race of ancient warriors who have awoken from centuries of cryosleep to find themselves at war with different factions.',
      coverUrl: 'https://images.igdb.com/igdb/image/upload/t_cover_big/co20wa.jpg',
      genres: ['Shooter', 'Role-playing (RPG)', 'Adventure'],
      firstReleaseDate: null,
      rating: 84.7,
      platforms: ['PC (Microsoft Windows)', 'PlayStation 4', 'Xbox One', 'Nintendo Switch', 'PlayStation 5', 'Xbox Series X|S', 'iOS'],
      similarGames: [1877, 119171],
    ),
    // 26. Portal 2
    const Game(
      id: 72,
      name: 'Portal 2',
      summary:
          'The sequel to the 2007 game Portal, Portal 2 is a first-person puzzle-platform game that challenges players to navigate spatial puzzles using a portal device.',
      coverUrl: 'https://images.igdb.com/igdb/image/upload/t_cover_big/co1rs4.jpg',
      genres: ['Shooter', 'Platform', 'Puzzle'],
      firstReleaseDate: null,
      rating: 94.2,
      platforms: ['PC (Microsoft Windows)', 'Mac', 'Linux', 'PlayStation 3', 'Xbox 360', 'Nintendo Switch'],
      similarGames: [233, 103298],
    ),
    // 27. Half-Life 2
    const Game(
      id: 233,
      name: 'Half-Life 2',
      summary:
          'By taking the suspense, challenge and visceral charge of the original, and adding startling new realism and responsiveness, Half-Life 2 opens the door to a world where the player\'s presence affects everything around him.',
      coverUrl: 'https://images.igdb.com/igdb/image/upload/t_cover_big/co1nmw.jpg',
      genres: ['Shooter', 'Puzzle'],
      firstReleaseDate: null,
      rating: 95.0,
      platforms: ['PC (Microsoft Windows)', 'Mac', 'Linux', 'Xbox 360', 'PlayStation 3'],
      similarGames: [72, 103298],
    ),
    // 28. Doom Eternal
    const Game(
      id: 103298,
      name: 'Doom Eternal',
      summary:
          'Hell\'s armies have invaded Earth. Become the Slayer in an epic single-player campaign to conquer demons across dimensions and stop the final destruction of humanity.',
      coverUrl: 'https://images.igdb.com/igdb/image/upload/t_cover_big/co1nc7.jpg',
      genres: ['Shooter'],
      firstReleaseDate: null,
      rating: 90.0,
      platforms: ['PC (Microsoft Windows)', 'PlayStation 4', 'Xbox One', 'Nintendo Switch', 'PlayStation 5', 'Xbox Series X|S'],
      similarGames: [72, 233],
    ),
    // 29. Resident Evil 4
    const Game(
      id: 19565,
      name: 'Resident Evil 4',
      summary:
          'Survival is only the beginning. Six years have passed since the biological disaster in Raccoon City. Leon S. Kennedy tracks the president\'s kidnapped daughter to a secluded European village.',
      coverUrl: 'https://images.igdb.com/igdb/image/upload/t_cover_big/co604n.jpg',
      genres: ['Shooter', 'Adventure'],
      firstReleaseDate: null,
      rating: 93.5,
      platforms: ['PC (Microsoft Windows)', 'PlayStation 4', 'PlayStation 5', 'Xbox Series X|S'],
      similarGames: [1020, 19560],
    ),
    // 30. Final Fantasy VII Remake
    const Game(
      id: 11156,
      name: 'Final Fantasy VII Remake',
      summary:
          'A spectacular reimagining of one of the most visionary games ever, Final Fantasy VII Remake rebuilds and expands the legendary RPG for today.',
      coverUrl: 'https://images.igdb.com/igdb/image/upload/t_cover_big/co1q84.jpg',
      genres: ['Role-playing (RPG)', 'Adventure', 'Hack and slash/Beat \'em up'],
      firstReleaseDate: null,
      rating: 89.0,
      platforms: ['PlayStation 4', 'PlayStation 5', 'PC (Microsoft Windows)'],
      similarGames: [1942, 1077],
    ),
    // 31. Chrono Trigger
    const Game(
      id: 1077,
      name: 'Chrono Trigger',
      summary:
          'When a newly developed teleportation device malfunctions at the Millennial Fair, young Crono must travel through time to rescue his unfortunate companion from an intricate web of past and present perils.',
      coverUrl: 'https://images.igdb.com/igdb/image/upload/t_cover_big/co1t44.jpg',
      genres: ['Role-playing (RPG)', 'Adventure', 'Turn-based strategy (TBS)'],
      firstReleaseDate: null,
      rating: 95.0,
      platforms: ['Super Nintendo Entertainment System (SNES)', 'PlayStation', 'Nintendo DS', 'PC (Microsoft Windows)', 'Android', 'iOS'],
      similarGames: [11156, 1070],
    ),
    // 32. The Last of Us Part I
    const Game(
      id: 205420,
      name: 'The Last of Us Part I',
      summary:
          'Experience the emotional storytelling and unforgettable characters in The Last of Us, winner of over 200 Game of the Year awards.',
      coverUrl: 'https://images.igdb.com/igdb/image/upload/t_cover_big/co59ak.jpg',
      genres: ['Shooter', 'Adventure'],
      firstReleaseDate: null,
      rating: 95.0,
      platforms: ['PlayStation 5', 'PC (Microsoft Windows)'],
      similarGames: [19560, 25076],
    ),
    // 33. Horizon Zero Dawn
    const Game(
      id: 11198,
      name: 'Horizon Zero Dawn',
      summary:
          'Experience Aloy\'s entire legendary quest to unravel the mysteries of a world ruled by deadly Machines. An outcast from her tribe, the young hunter fights to uncover her past.',
      coverUrl: 'https://images.igdb.com/igdb/image/upload/t_cover_big/co242r.jpg',
      genres: ['Role-playing (RPG)', 'Shooter', 'Adventure'],
      firstReleaseDate: null,
      rating: 90.0,
      platforms: ['PlayStation 4', 'PC (Microsoft Windows)'],
      similarGames: [1942, 19560, 7346],
    ),
    // 34. FIFA 23
    const Game(
      id: 205423,
      name: 'FIFA 23',
      summary:
          'EA SPORTS FIFA 23 brings The World\'s Game to the pitch, with HyperMotion2 Technology that delivers even more gameplay realism, men\'s and women\'s FIFA World Cup tournaments, cross-play features, and more.',
      coverUrl: 'https://images.igdb.com/igdb/image/upload/t_cover_big/co58ao.jpg',
      genres: ['Sport', 'Simulator'],
      firstReleaseDate: null,
      rating: 78.0,
      platforms: ['PC (Microsoft Windows)', 'PlayStation 4', 'PlayStation 5', 'Xbox One', 'Xbox Series X|S', 'Nintendo Switch'],
      similarGames: [1020],
    ),
  ];
}
