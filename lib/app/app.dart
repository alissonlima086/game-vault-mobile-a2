import 'package:flutter/material.dart';
import '../repositories/repositories.dart';
import '../services/services.dart';
import '../viewmodels/viewmodels.dart';
import 'router.dart';

class MobileA2App extends StatefulWidget {
  final IIgdbService igdbService;
  final IGameRepository gameRepository;
  final IAuthService? authService;
  final AuthViewModel? authViewModel;

  const MobileA2App({
    super.key,
    required this.igdbService,
    required this.gameRepository,
    this.authService,
    this.authViewModel,
  });

  @override
  State<MobileA2App> createState() => _MobileA2AppState();
}

class _MobileA2AppState extends State<MobileA2App> {
  late final SearchViewModel _searchViewModel;
  late final LibraryViewModel _libraryViewModel;
  AuthViewModel? _authViewModel;
  bool _ownsAuthViewModel = false;

  @override
  void initState() {
    super.initState();
    _searchViewModel = SearchViewModel(service: widget.igdbService);
    _libraryViewModel = LibraryViewModel(repo: widget.gameRepository);

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
  void dispose() {
    _authViewModel?.removeListener(_onAuthChanged);
    if (_ownsAuthViewModel) {
      _authViewModel?.dispose();
    }
    _searchViewModel.dispose();
    _libraryViewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF6366F1); // Indigo moderno

    return MaterialApp(
      title: 'ZVault • Mobile A2',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      initialRoute: AppRoutes.home,
      onGenerateRoute: (settings) => AppRouter.onGenerateRoute(
        settings,
        igdbService: widget.igdbService,
        gameRepository: widget.gameRepository,
        searchViewModel: _searchViewModel,
        libraryViewModel: _libraryViewModel,
        authViewModel: _authViewModel,
      ),
    );
  }
}
