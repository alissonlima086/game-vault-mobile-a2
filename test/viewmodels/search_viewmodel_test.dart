import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_a2/models/game.dart';
import 'package:mobile_a2/services/igdb_service.dart';
import 'package:mobile_a2/viewmodels/search_viewmodel.dart';
import 'package:mocktail/mocktail.dart';

class MockIgdbService extends Mock implements IIgdbService {}

void main() {
  late MockIgdbService mockService;
  late SearchViewModel viewModel;

  setUp(() {
    mockService = MockIgdbService();
    when(() => mockService.isFallbackMode).thenReturn(false);
    viewModel = SearchViewModel(service: mockService);
  });

  group('SearchViewModel - Validação do Formulário', () {
    test('Deve rejeitar termo vazio ou nulo', () {
      expect(viewModel.validateQuery(null), isNotNull);
      expect(viewModel.validateQuery(''), isNotNull);
      expect(viewModel.validateQuery('   '), isNotNull);
    });

    test('Deve rejeitar termo com menos de 2 caracteres', () {
      expect(viewModel.validateQuery('a'), isNotNull);
      expect(viewModel.validateQuery(' 1 '), isNotNull);
    });

    test('Deve rejeitar termo com mais de 100 caracteres', () {
      final longQuery = 'a' * 101;
      expect(viewModel.validateQuery(longQuery), isNotNull);
    });

    test('Deve aceitar termo válido', () {
      expect(viewModel.validateQuery('Warframe'), isNull);
      expect(viewModel.validateQuery('GTA V'), isNull);
    });
  });

  group('SearchViewModel - Estados da Busca', () {
    test('Estado inicial deve ser initial com resultados vazios', () {
      expect(viewModel.state, SearchState.initial);
      expect(viewModel.results, isEmpty);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.errorMessage, isNull);
    });

    test('Deve transitar para loading e depois success com jogos encontrados', () async {
      const mockGames = [
        Game(id: 1, name: 'Hollow Knight'),
        Game(id: 2, name: 'Celeste'),
      ];

      when(() => mockService.searchGames('indie', limit: any(named: 'limit')))
          .thenAnswer((_) async => mockGames);

      final states = <SearchState>[];
      viewModel.addListener(() => states.add(viewModel.state));

      await viewModel.search('indie');

      expect(states, contains(SearchState.loading));
      expect(viewModel.state, SearchState.success);
      expect(viewModel.results.length, 2);
      expect(viewModel.results.first.name, 'Hollow Knight');
      expect(viewModel.hasResults, isTrue);
    });

    test('Deve transitar para empty quando nenhum jogo for encontrado', () async {
      when(() => mockService.searchGames('xyz123abc', limit: any(named: 'limit')))
          .thenAnswer((_) async => []);

      await viewModel.search('xyz123abc');

      expect(viewModel.state, SearchState.empty);
      expect(viewModel.results, isEmpty);
      expect(viewModel.errorMessage, isNull);
    });

    test('Deve transitar para error quando o serviço lançar IgdbException', () async {
      when(() => mockService.searchGames('error_query', limit: any(named: 'limit')))
          .thenThrow(const IgdbException('Servidor indisponível', statusCode: 502));

      await viewModel.search('error_query');

      expect(viewModel.state, SearchState.error);
      expect(viewModel.results, isEmpty);
      expect(viewModel.errorMessage, 'Servidor indisponível');
    });

    test('Deve resetar estado para initial ao chamar clear()', () async {
      when(() => mockService.searchGames('Portal', limit: any(named: 'limit')))
          .thenAnswer((_) async => [const Game(id: 72, name: 'Portal 2')]);

      await viewModel.search('Portal');
      expect(viewModel.state, SearchState.success);

      viewModel.clear();
      expect(viewModel.state, SearchState.initial);
      expect(viewModel.results, isEmpty);
      expect(viewModel.currentQuery, isEmpty);
    });
  });
}
