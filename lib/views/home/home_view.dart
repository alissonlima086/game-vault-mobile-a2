import 'package:flutter/material.dart';
import '../../models/game.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/library_viewmodel.dart';

class HomeView extends StatelessWidget {
  final LibraryViewModel libraryViewModel;
  final AuthViewModel? authViewModel;
  final VoidCallback onNavigateToSearch;
  final VoidCallback onNavigateToLibrary;
  final Function(Game game)? onGameSelected;

  const HomeView({
    super.key,
    required this.libraryViewModel,
    this.authViewModel,
    required this.onNavigateToSearch,
    required this.onNavigateToLibrary,
    this.onGameSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.videogame_asset, color: colorScheme.primary),
            const SizedBox(width: 10),
            const Text(
              'ZVault',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: ListenableBuilder(
        listenable: authViewModel != null
            ? Listenable.merge([libraryViewModel, authViewModel!])
            : libraryViewModel,
        builder: (context, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Card de Autenticação / Perfil (Google OAuth2 + Supabase)
                    if (authViewModel != null) ...[
                      _buildAuthCard(context, colorScheme),
                      const SizedBox(height: 20),
                    ],

                    // Estatísticas da Biblioteca
                    Text(
                      'Visão Geral da Biblioteca',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildStatsRow(context, colorScheme),
                    const SizedBox(height: 28),

                    // Preview de 4 Jogos Adicionados Recentemente
                    _buildRecentGamesSection(context, colorScheme),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAuthCard(BuildContext context, ColorScheme colorScheme) {
    final vm = authViewModel!;
    final user = vm.currentUser;

    if (vm.isAuthenticated && user != null) {
      return Card(
        elevation: 0,
        color: colorScheme.primaryContainer.withAlpha(80),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.primary.withAlpha(80)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: colorScheme.primary,
                backgroundImage:
                    user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                child: user.avatarUrl == null
                    ? Text(
                        user.displayName.isNotEmpty
                            ? user.displayName[0].toUpperCase()
                            : 'U',
                        style: TextStyle(
                          color: colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Olá, ${user.displayName}!',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Sincronizado na nuvem (${user.email})',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => vm.signOut(),
                icon: const Icon(Icons.logout, size: 16),
                label: const Text('Sair'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withAlpha(90),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withAlpha(70)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_sync_outlined, color: colorScheme.primary, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Sincronize sua biblioteca',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Conecte sua conta Google para salvar seus jogos na nuvem e acessá-los de qualquer dispositivo.',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (vm.status == AuthStatus.error && vm.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                vm.errorMessage!,
                style: TextStyle(fontSize: 12, color: colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: vm.status == AuthStatus.authenticating
                  ? null
                  : () => vm.signInWithGoogle(),
              icon: vm.status == AuthStatus.authenticating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.login, size: 18),
              label: Text(
                vm.status == AuthStatus.authenticating
                    ? 'Conectando...'
                    : 'Entrar com Google',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context, ColorScheme colorScheme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;
        final cards = [
          _buildStatCard(
            context,
            title: 'Total',
            count: libraryViewModel.totalCount,
            icon: Icons.games,
            color: colorScheme.primary,
          ),
          _buildStatCard(
            context,
            title: GameStatus.wishlist.label,
            count: libraryViewModel.countForStatus(GameStatus.wishlist),
            icon: GameStatus.wishlist.icon,
            color: GameStatus.wishlist.color,
          ),
          _buildStatCard(
            context,
            title: GameStatus.playing.label,
            count: libraryViewModel.countForStatus(GameStatus.playing),
            icon: GameStatus.playing.icon,
            color: GameStatus.playing.color,
          ),
          _buildStatCard(
            context,
            title: GameStatus.completed.label,
            count: libraryViewModel.countForStatus(GameStatus.completed),
            icon: GameStatus.completed.icon,
            color: GameStatus.completed.color,
          ),
        ];

        if (isNarrow) {
          return GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.8,
            children: cards,
          );
        }

        return Row(
          children: cards
              .map((c) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: c,
                    ),
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: color.withAlpha(25),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.withAlpha(80)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '$count',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentGamesSection(BuildContext context, ColorScheme colorScheme) {
    final theme = Theme.of(context);
    final recentEntries = libraryViewModel.recentEntries;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: colorScheme.primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Adicionados Recentemente',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (recentEntries.isNotEmpty)
              TextButton.icon(
                onPressed: onNavigateToLibrary,
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('Ver todos'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (recentEntries.isEmpty)
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerHighest.withAlpha(70),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colorScheme.outlineVariant.withAlpha(70)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.videogame_asset_outlined,
                      size: 48,
                      color: colorScheme.onSurfaceVariant.withAlpha(140),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Sua biblioteca ainda está vazia',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pesquise jogos da IGDB e adicione-os para acompanhar seus status aqui.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: onNavigateToSearch,
                      icon: const Icon(Icons.search, size: 18),
                      label: const Text('Pesquisar Jogos na IGDB'),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 600;
              final crossAxisCount = isNarrow ? 2 : 4;

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recentEntries.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: isNarrow ? 0.68 : 0.65,
                ),
                itemBuilder: (context, index) {
                  final entry = recentEntries[index];
                  return _buildRecentGameCard(context, entry, colorScheme);
                },
              );
            },
          ),
      ],
    );
  }

  Widget _buildRecentGameCard(
    BuildContext context,
    LibraryEntry entry,
    ColorScheme colorScheme,
  ) {
    final game = entry.game;

    return Card(
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colorScheme.outlineVariant.withAlpha(70)),
      ),
      child: InkWell(
        onTap: () {
          if (onGameSelected != null) {
            onGameSelected!(game);
          } else {
            onNavigateToLibrary();
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Capa do Jogo
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  game.coverUrl != null
                      ? Image.network(
                          game.coverUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildPlaceholder(colorScheme),
                        )
                      : _buildPlaceholder(colorScheme),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(180),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(entry.status.icon, size: 12, color: entry.status.color),
                          const SizedBox(width: 4),
                          Text(
                            entry.status.label,
                            style: TextStyle(
                              color: entry.status.color,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Informações do Jogo
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        game.releaseYear != 'N/A' ? game.releaseYear : 'N/D',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (game.rating != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, size: 12, color: Colors.amber),
                            const SizedBox(width: 2),
                            Text(
                              game.rating!.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.videogame_asset_outlined,
          size: 36,
          color: colorScheme.onSurfaceVariant.withAlpha(100),
        ),
      ),
    );
  }
}
