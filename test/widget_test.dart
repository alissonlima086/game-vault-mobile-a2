import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_a2/app/app.dart';
import 'package:mobile_a2/models/game.dart';
import 'package:mobile_a2/repositories/game_repository.dart';
import 'package:mobile_a2/services/igdb_service.dart';
import 'package:mocktail/mocktail.dart';

class MockIgdbService extends Mock implements IIgdbService {}

void main() {
  late MockIgdbService mockService;
  late InMemoryGameRepository gameRepository;

  const sampleGame = Game(
    id: 265,
    name: 'Warframe',
    summary: 'A fast-paced cooperative third-person shooter set in space.',
    genres: ['Shooter', 'Action'],
    rating: 85.0,
  );

  setUp(() {
    mockService = MockIgdbService();
    when(() => mockService.isFallbackMode).thenReturn(false);
    gameRepository = InMemoryGameRepository();
  });

  tearDown(() {
    gameRepository.dispose();
  });

  testWidgets('MobileA2App - Renderiza Home, navega para Pesquisa, Detalhes e Biblioteca', (WidgetTester tester) async {
    when(() => mockService.searchGames('Warframe', limit: any(named: 'limit')))
        .thenAnswer((_) async => [sampleGame]);

    await tester.pumpWidget(
      MobileA2App(
        igdbService: mockService,
        gameRepository: gameRepository,
      ),
    );

    // 1. Verifica renderização da Home View
    expect(find.text('ZVault'), findsOneWidget);
    expect(find.text('Visão Geral da Biblioteca'), findsOneWidget);
    expect(find.text('Adicionados Recentemente'), findsOneWidget);

    // 2. Navega para a tela de Pesquisa pelo botão de ação
    final searchButton = find.text('Pesquisar Jogos na IGDB');
    expect(searchButton, findsOneWidget);
    await tester.tap(searchButton);
    await tester.pumpAndSettle();

    // 3. Verifica se a tela de Pesquisa abriu e valida formulário
    expect(find.text('Pesquisar'), findsOneWidget);
    expect(find.text('Encontre seus jogos favoritos'), findsOneWidget); // Estado Inicial

    // Tenta submeter busca vazia
    final submitButton = find.widgetWithText(FilledButton, 'Buscar');
    await tester.tap(submitButton);
    await tester.pumpAndSettle();
    expect(find.text('Por favor, digite o nome de um jogo.'), findsOneWidget);

    // Digita termo válido
    await tester.enterText(find.byType(TextFormField), 'Warframe');
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    // 4. Verifica se o resultado da IGDB é exibido (Estado Sucesso)
    expect(find.widgetWithText(Card, 'Warframe'), findsOneWidget);
    expect(find.text('A fast-paced cooperative third-person shooter set in space.'), findsOneWidget);

    // 5. Clica no card do jogo para navegar para a tela de Detalhes
    await tester.tap(find.widgetWithText(Card, 'Warframe'));
    await tester.pumpAndSettle();

    // Verifica tela de Detalhes e presença da NavigationBar fixa
    expect(find.text('Gerenciar na Biblioteca'), findsOneWidget);
    expect(find.text('Status do Jogo:'), findsOneWidget);
    expect(find.text('Adicionar à Biblioteca'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    // Adiciona o jogo à biblioteca
    await tester.ensureVisible(find.text('Adicionar à Biblioteca'));
    await tester.tap(find.text('Adicionar à Biblioteca'));
    await tester.pumpAndSettle();

    // Verifica se o botão mudou para "Atualizar na Biblioteca" e botão "Remover" apareceu
    expect(find.text('Atualizar na Biblioteca'), findsOneWidget);
    expect(find.text('Remover'), findsOneWidget);

    // Volta para o shell
    await tester.pageBack();
    await tester.pumpAndSettle();

    // 6. Navega para a Minha Biblioteca pela NavigationBar
    final libraryNavDestination = find.text('Biblioteca');
    expect(libraryNavDestination, findsOneWidget);
    await tester.tap(libraryNavDestination);
    await tester.pumpAndSettle();

    // Verifica tela da Biblioteca com o jogo adicionado
    expect(find.text('Minha Biblioteca'), findsOneWidget);
    expect(find.text('Warframe'), findsOneWidget);
    expect(find.text('Quero jogar'), findsWidgets);
  });
}
