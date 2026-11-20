import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_a2/services/igdb_service.dart';

void main() {
  group('IgdbService - Fallback & Catálogo Curado', () {
    late IgdbService service;

    setUp(() {
      // Sem cliente Supabase passado, deve operar via fallback no catálogo curado
      service = IgdbService(enableFallbackOn404: true);
    });

    test('Deve rejeitar termos com menos de 2 caracteres', () async {
      expect(() => service.searchGames('a'), throwsA(isA<IgdbException>()));
      expect(() => service.searchGames(' '), throwsA(isA<IgdbException>()));
    });

    test('Deve encontrar jogos icônicos simples no catálogo curado', () async {
      // Teste de jogos que antes não apareciam
      final marioGames = await service.searchGames('Mario');
      expect(marioGames, isNotEmpty);
      expect(marioGames.any((g) => g.name.contains('Mario')), isTrue);
      expect(service.isFallbackMode, isTrue);

      final zeldaGames = await service.searchGames('Zelda');
      expect(zeldaGames, isNotEmpty);
      expect(zeldaGames.any((g) => g.name.contains('Zelda')), isTrue);

      final minecraft = await service.searchGames('Minecraft');
      expect(minecraft, isNotEmpty);
      expect(minecraft.first.name, 'Minecraft');

      final godOfWar = await service.searchGames('God of War');
      expect(godOfWar, isNotEmpty);
      expect(godOfWar.any((g) => g.name.contains('God of War')), isTrue);
    });

    test('Deve ser insensível a acentuação e maiúsculas/minúsculas', () async {
      final pokemonNoAccent = await service.searchGames('pokemon');
      final pokemonWithAccent = await service.searchGames('Pokémon');
      expect(pokemonNoAccent, isNotEmpty);
      expect(pokemonWithAccent, isNotEmpty);
      expect(pokemonNoAccent.first.name, pokemonWithAccent.first.name);
    });

    test('Deve priorizar busca por título antes de gênero ou sinopse', () async {
      // Quando busca "Mario", deve trazer Super Mario, e não jogos cuja descrição contenha palavras aleatórias
      final results = await service.searchGames('Mario');
      for (final game in results) {
        expect(game.name.toLowerCase().contains('mario'), isTrue);
      }
    });

    test('Deve recuperar recomendações por IDs no fallback', () async {
      final games = await service.getGamesByIds([26758, 7346]);
      expect(games.length, 2);
      expect(games.any((g) => g.name.contains('Mario')), isTrue);
      expect(games.any((g) => g.name.contains('Zelda')), isTrue);
    });
  });
}
