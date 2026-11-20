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

    test('Deve serializar e deserializar LibraryEntry para/de Supabase JSON', () {
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
      expect(json['game_name'], 'Hades');
      expect(json['status'], 'playing');
      expect(json['user_id'], 'user-abc');
      expect(json['notes'], 'Espada Estígia');
      expect(json['user_rating'], 10);

      final reconstructed = LibraryEntry.fromSupabaseJson(json);
      expect(reconstructed.id, equals('uuid-1234'));
      expect(reconstructed.userId, equals('user-abc'));
      expect(reconstructed.game.id, equals(42));
      expect(reconstructed.game.name, equals('Hades'));
      expect(reconstructed.status, equals(GameStatus.playing));
      expect(reconstructed.notes, equals('Espada Estígia'));
      expect(reconstructed.userRating, equals(10));
    });
  });
}
