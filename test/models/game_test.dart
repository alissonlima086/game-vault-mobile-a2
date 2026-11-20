import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_a2/models/game.dart';

void main() {
  group('Game Model & Deserialização IGDB', () {
    test('Deve converter JSON completo da IGDB / Edge Function corretamente', () {
      final json = {
        'id': 1942,
        'name': 'The Witcher 3: Wild Hunt',
        'summary': 'Um RPG épico de mundo aberto...',
        'storyline': 'Geralt procura Ciri...',
        'cover_url': '//images.igdb.com/igdb/image/upload/t_thumb/co1wyy.jpg',
        'genres': ['Role-playing (RPG)', 'Adventure'],
        'first_release_date': 1431993600, // 2015-05-19
        'rating': 95.84,
        'platforms': ['PC (Microsoft Windows)', 'PlayStation 4', 'Xbox One'],
        'similar_games': [121, 472],
      };

      final game = Game.fromJson(json);

      expect(game.id, 1942);
      expect(game.name, 'The Witcher 3: Wild Hunt');
      expect(game.summary, 'Um RPG épico de mundo aberto...');
      expect(game.storyline, 'Geralt procura Ciri...');
      // Verifica normalização da URL da capa para https e t_cover_big
      expect(game.coverUrl, 'https://images.igdb.com/igdb/image/upload/t_cover_big/co1wyy.jpg');
      expect(game.genres, contains('Role-playing (RPG)'));
      expect(game.firstReleaseDate?.year, 2015);
      expect(game.releaseYear, '2015');
      expect(game.rating, 95.8);
      expect(game.platforms, contains('PlayStation 4'));
      expect(game.similarGames, [121, 472]);
    });

    test('Deve tratar campos nulos ou ausentes com segurança', () {
      final json = {
        'id': 100,
        'name': 'Jogo Minimalista',
      };

      final game = Game.fromJson(json);

      expect(game.id, 100);
      expect(game.name, 'Jogo Minimalista');
      expect(game.summary, isNull);
      expect(game.coverUrl, isNull);
      expect(game.genres, isEmpty);
      expect(game.platforms, isEmpty);
      expect(game.firstReleaseDate, isNull);
      expect(game.releaseYear, 'N/A');
      expect(game.shortDescription, 'Sem descrição disponível.');
    });

    test('Deve serializar para Map via toJson()', () {
      const game = Game(
        id: 1,
        name: 'Portal',
        summary: 'Puzzle game',
      );

      final map = game.toJson();
      expect(map['id'], 1);
      expect(map['name'], 'Portal');
      expect(map['summary'], 'Puzzle game');
    });

    test('Deve converter GameStatus de strings com tolerância', () {
      expect(GameStatus.fromString('wishlist'), GameStatus.wishlist);
      expect(GameStatus.fromString('Quero Jogar'), GameStatus.wishlist);
      expect(GameStatus.fromString('owned'), GameStatus.owned);
      expect(GameStatus.fromString('tenho'), GameStatus.owned);
      expect(GameStatus.fromString('playing'), GameStatus.playing);
      expect(GameStatus.fromString('completed'), GameStatus.completed);
      expect(GameStatus.fromString('concluído'), GameStatus.completed);
      expect(GameStatus.fromString('desconhecido'), GameStatus.wishlist);
    });

    test('Deve serializar LibraryEntry para formato da tabela associativa (toSupabaseJson)', () {
      const game = Game(id: 42, name: 'Hades');
      final entry = LibraryEntry(
        id: 'uuid-1234',
        userId: 'user-abc',
        game: game,
        status: GameStatus.playing,
        addedAt: DateTime.parse('2026-11-19T10:00:00Z'),
        notes: 'Espada Estígia',
        userRating: 10,
      );

      final json = entry.toSupabaseJson();
      expect(json['game_id'], 42);
      expect(json.containsKey('game_name'), isFalse);
      expect(json.containsKey('game_data'), isFalse);
      expect(json['status'], 'playing');
      expect(json['user_id'], 'user-abc');
      expect(json['notes'], 'Espada Estígia');
      expect(json['user_rating'], 10);
    });

    test('Deve serializar Game para formato da tabela games (toGamesTableJson)', () {
      const game = Game(
        id: 777,
        name: 'Cyberpunk 2077',
        summary: 'RPG futurista',
        rating: 86.5,
      );

      final map = game.toGamesTableJson();
      expect(map['id'], 777);
      expect(map['name'], 'Cyberpunk 2077');
      expect(map['summary'], 'RPG futurista');
      expect(map['rating'], 86.5);
      expect(map['raw_data'], isA<Map<String, dynamic>>());
      expect((map['raw_data'] as Map)['id'], 777);
    });

    test('Deve deserializar LibraryEntry a partir da relação normalizada game:games(*)', () {
      final normalizedJson = {
        'id': 'entry-99',
        'user_id': 'user-xyz',
        'game_id': 1942,
        'status': 'completed',
        'created_at': '2026-11-20T12:00:00Z',
        'notes': 'Finalizado com 120 horas',
        'user_rating': 10,
        'game': {
          'id': 1942,
          'name': 'The Witcher 3: Wild Hunt',
          'cover_url': 'https://images.igdb.com/cover.jpg',
          'summary': 'Geralt de Rivia em busca de Ciri',
          'rating': 95.8,
          'raw_data': {
            'id': 1942,
            'name': 'The Witcher 3: Wild Hunt',
            'cover_url': 'https://images.igdb.com/cover.jpg',
            'summary': 'Geralt de Rivia em busca de Ciri',
            'genres': ['RPG', 'Aventura'],
          },
        },
      };

      final entry = LibraryEntry.fromSupabaseJson(normalizedJson);
      expect(entry.id, 'entry-99');
      expect(entry.userId, 'user-xyz');
      expect(entry.status, GameStatus.completed);
      expect(entry.notes, 'Finalizado com 120 horas');
      expect(entry.userRating, 10);
      expect(entry.game.id, 1942);
      expect(entry.game.name, 'The Witcher 3: Wild Hunt');
      expect(entry.game.genres, contains('RPG'));
    });
  });
}
