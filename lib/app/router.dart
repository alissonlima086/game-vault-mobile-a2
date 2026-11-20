import 'package:flutter/material.dart';
import '../models/models.dart';
import '../repositories/repositories.dart';
import '../services/services.dart';
import '../viewmodels/viewmodels.dart';
import '../views/views.dart';

/// Adicionando rotas especificas para as páginas
class AppRoutes {
  static const String home = '/';
  static const String search = '/search';
  static const String library = '/library';
  static const String details = '/details';
}

/// Mapear as URLs e injetar ViewModels da aplicação
class AppRouter {
  static Route<dynamic> onGenerateRoute(
    RouteSettings settings, {
    required IIgdbService igdbService,
    required IGameRepository gameRepository,
    required SearchViewModel searchViewModel,
    required LibraryViewModel libraryViewModel,
    AuthViewModel? authViewModel,
  }) {
    final rawName = settings.name ?? AppRoutes.home;
    final uri = Uri.tryParse(rawName) ?? Uri(path: rawName);
    final path = uri.path.isEmpty ? AppRoutes.home : uri.path;

    switch (path) {
      case AppRoutes.home:
      case '/home':
        return MaterialPageRoute(
          settings: const RouteSettings(name: AppRoutes.home),
          builder: (context) => MainNavigationShell(
            igdbService: igdbService,
            gameRepository: gameRepository,
            searchViewModel: searchViewModel,
            libraryViewModel: libraryViewModel,
            authViewModel: authViewModel,
            initialIndex: 0,
          ),
        );

      case AppRoutes.search:
        return MaterialPageRoute(
          settings: const RouteSettings(name: AppRoutes.search),
          builder: (context) => MainNavigationShell(
            igdbService: igdbService,
            gameRepository: gameRepository,
            searchViewModel: searchViewModel,
            libraryViewModel: libraryViewModel,
            authViewModel: authViewModel,
            initialIndex: 1,
          ),
        );

      case AppRoutes.library:
        return MaterialPageRoute(
          settings: const RouteSettings(name: AppRoutes.library),
          builder: (context) => MainNavigationShell(
            igdbService: igdbService,
            gameRepository: gameRepository,
            searchViewModel: searchViewModel,
            libraryViewModel: libraryViewModel,
            authViewModel: authViewModel,
            initialIndex: 2,
          ),
        );

      case AppRoutes.details:
        Game? game;
        int sourceIndex = 0;
        if (settings.arguments is Game) {
          game = settings.arguments as Game;
        } else if (settings.arguments is Map) {
          final map = settings.arguments as Map;
          if (map['game'] is Game) {
            game = map['game'] as Game;
          }
          if (map['sourceIndex'] is int) {
            sourceIndex = map['sourceIndex'] as int;
          }
        } else if (uri.queryParameters.containsKey('id')) {
          final id = int.tryParse(uri.queryParameters['id']!);
          if (id != null) {
            game = Game(
              id: id,
              name: uri.queryParameters['name'] ?? 'Jogo #$id',
            );
          }
        }

        if (game == null) {
          return MaterialPageRoute(
            settings: const RouteSettings(name: AppRoutes.home),
            builder: (context) => MainNavigationShell(
              igdbService: igdbService,
              gameRepository: gameRepository,
              searchViewModel: searchViewModel,
              libraryViewModel: libraryViewModel,
              authViewModel: authViewModel,
              initialIndex: 0,
            ),
          );
        }

        return MaterialPageRoute(
          settings: RouteSettings(
            name: '${AppRoutes.details}?id=${game.id}',
            arguments: settings.arguments ?? game,
          ),
          builder: (context) => MainNavigationShell(
            igdbService: igdbService,
            gameRepository: gameRepository,
            searchViewModel: searchViewModel,
            libraryViewModel: libraryViewModel,
            authViewModel: authViewModel,
            initialIndex: sourceIndex,
            selectedGame: game,
          ),
        );

      default:
        return MaterialPageRoute(
          settings: const RouteSettings(name: AppRoutes.home),
          builder: (context) => MainNavigationShell(
            igdbService: igdbService,
            gameRepository: gameRepository,
            searchViewModel: searchViewModel,
            libraryViewModel: libraryViewModel,
            authViewModel: authViewModel,
            initialIndex: 0,
          ),
        );
    }
  }
}

/// Shell principal responsivo com navegação inferior e sincronização de rotas com a barra de URL.
class MainNavigationShell extends StatefulWidget {
  final IIgdbService igdbService;
  final IGameRepository gameRepository;
  final IAuthService? authService;
  final AuthViewModel? authViewModel;
  final SearchViewModel? searchViewModel;
  final LibraryViewModel? libraryViewModel;
  final int initialIndex;
  final Game? selectedGame;

  const MainNavigationShell({
    super.key,
    required this.igdbService,
    required this.gameRepository,
    this.authService,
    this.authViewModel,
    this.searchViewModel,
    this.libraryViewModel,
    this.initialIndex = 0,
    this.selectedGame,
  });

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  late int _currentIndex;
  late final SearchViewModel _searchViewModel;
  late final LibraryViewModel _libraryViewModel;
  GameDetailsViewModel? _detailsViewModel;
  AuthViewModel? _authViewModel;
  bool _ownsSearchViewModel = false;
  bool _ownsLibraryViewModel = false;
  bool _ownsAuthViewModel = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;

    if (widget.selectedGame != null) {
      _detailsViewModel = GameDetailsViewModel(
        game: widget.selectedGame!,
        repo: widget.gameRepository,
        igdbService: widget.igdbService,
      );
    }

    if (widget.searchViewModel != null) {
      _searchViewModel = widget.searchViewModel!;
    } else {
      _searchViewModel = SearchViewModel(service: widget.igdbService);
      _ownsSearchViewModel = true;
    }

    if (widget.libraryViewModel != null) {
      _libraryViewModel = widget.libraryViewModel!;
    } else {
      _libraryViewModel = LibraryViewModel(repo: widget.gameRepository);
      _ownsLibraryViewModel = true;
    }

    if (widget.authViewModel != null) {
      _authViewModel = widget.authViewModel;
    } else if (widget.authService != null) {
      _authViewModel = AuthViewModel(authService: widget.authService!);
      _ownsAuthViewModel = true;
    }

    if (_authViewModel != null) {
      _libraryViewModel.updateCurrentUser(_authViewModel!.currentUser?.id);
      _authViewModel!.addListener(_onAuthChanged);
    }
  }

  void _onAuthChanged() {
    _libraryViewModel.updateCurrentUser(_authViewModel?.currentUser?.id, reload: true);
  }

  @override
  void didUpdateWidget(MainNavigationShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialIndex != _currentIndex) {
      setState(() {
        _currentIndex = widget.initialIndex;
      });
    }

    if (widget.selectedGame != oldWidget.selectedGame) {
      if (widget.selectedGame != null) {
        _detailsViewModel?.dispose();
        _detailsViewModel = GameDetailsViewModel(
          game: widget.selectedGame!,
          repo: widget.gameRepository,
          igdbService: widget.igdbService,
        );
      } else {
        _detailsViewModel?.dispose();
        _detailsViewModel = null;
      }
    }
  }

  @override
  void dispose() {
    _detailsViewModel?.dispose();
    _authViewModel?.removeListener(_onAuthChanged);
    if (_ownsAuthViewModel) {
      _authViewModel?.dispose();
    }
    if (_ownsSearchViewModel) {
      _searchViewModel.dispose();
    }
    if (_ownsLibraryViewModel) {
      _libraryViewModel.dispose();
    }
    super.dispose();
  }

  void _navigateToDetails(Game game) {
    Navigator.of(context).pushNamed(
      '${AppRoutes.details}?id=${game.id}',
      arguments: {
        'game': game,
        'sourceIndex': _currentIndex,
      },
    );
  }

  void _onDestinationSelected(int index) {
    if (widget.selectedGame != null) {
      if (index == _currentIndex && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
        return;
      }
      switch (index) {
        case 0:
          Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
          break;
        case 1:
          Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.search, (route) => false);
          break;
        case 2:
          Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.library, (route) => false);
          break;
      }
      return;
    }

    if (index == _currentIndex) return;
    switch (index) {
      case 0:
        Navigator.of(context).pushReplacementNamed(AppRoutes.home);
        break;
      case 1:
        Navigator.of(context).pushReplacementNamed(AppRoutes.search);
        break;
      case 2:
        Navigator.of(context).pushReplacementNamed(AppRoutes.library);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (widget.selectedGame != null && _detailsViewModel != null) {
      content = GameDetailsView(
        viewModel: _detailsViewModel!,
        onSelectSimilarGame: _navigateToDetails,
      );
    } else {
      final screens = [
        HomeView(
          libraryViewModel: _libraryViewModel,
          authViewModel: _authViewModel,
          onNavigateToSearch: () => Navigator.of(context).pushReplacementNamed(AppRoutes.search),
          onNavigateToLibrary: () => Navigator.of(context).pushReplacementNamed(AppRoutes.library),
          onGameSelected: _navigateToDetails,
        ),
        SearchView(
          viewModel: _searchViewModel,
          onGameSelected: _navigateToDetails,
        ),
        LibraryView(
          viewModel: _libraryViewModel,
          authViewModel: _authViewModel,
          onGameSelected: _navigateToDetails,
          onNavigateToSearch: () => Navigator.of(context).pushReplacementNamed(AppRoutes.search),
        ),
      ];
      content = screens[_currentIndex];
    }

    return Scaffold(
      body: content,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Pesquisa',
          ),
          NavigationDestination(
            icon: Icon(Icons.collections_bookmark_outlined),
            selectedIcon: Icon(Icons.collections_bookmark),
            label: 'Biblioteca',
          ),
        ],
      ),
    );
  }
}
