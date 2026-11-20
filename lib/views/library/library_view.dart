import 'package:flutter/material.dart';
import '../../models/game.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/library_viewmodel.dart';

class LibraryView extends StatelessWidget {
  final LibraryViewModel viewModel;
  final AuthViewModel? authViewModel;
  final Function(Game game) onGameSelected;
  final VoidCallback onNavigateToSearch;

  const LibraryView({
    super.key,
    required this.viewModel,
    this.authViewModel,
    required this.onGameSelected,
    required this.onNavigateToSearch,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minha Biblioteca'),
      ),
      body: ListenableBuilder(
        listenable: authViewModel != null
            ? Listenable.merge([viewModel, authViewModel!])
            : viewModel,
        builder: (context, _) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                children: [
                  const SizedBox(height: 8),

                  // Filtros por Status (Chips / Tabs)
                  _buildFilterChips(context, colorScheme),
                  const Divider(height: 1),

                  // Conteúdo da Biblioteca
                  Expanded(
                    child: viewModel.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : viewModel.filteredEntries.isEmpty
                            ? _buildEmptyState(context, colorScheme)
                            : _buildLibraryList(context, colorScheme),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context, ColorScheme colorScheme) {
    final filters = [
      _FilterOption(null, 'Todos (${viewModel.filteredEntries.length})', Icons.apps),
      _FilterOption(
        GameStatus.wishlist,
        '${GameStatus.wishlist.label} (${viewModel.countForStatus(GameStatus.wishlist)})',
        GameStatus.wishlist.icon,
      ),
      _FilterOption(
        GameStatus.playing,
        '${GameStatus.playing.label} (${viewModel.countForStatus(GameStatus.playing)})',
        GameStatus.playing.icon,
      ),
      _FilterOption(
        GameStatus.owned,
        '${GameStatus.owned.label} (${viewModel.countForStatus(GameStatus.owned)})',
        GameStatus.owned.icon,
      ),
      _FilterOption(
        GameStatus.completed,
        '${GameStatus.completed.label} (${viewModel.countForStatus(GameStatus.completed)})',
        GameStatus.completed.icon,
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: filters.map((option) {
          final isSelected = viewModel.selectedFilter == option.status;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              avatar: Icon(
                option.icon,
                size: 16,
                color: isSelected
                    ? Colors.white
                    : (option.status?.color ?? colorScheme.primary),
              ),
              label: Text(option.label),
              selected: isSelected,
              selectedColor: option.status?.color ?? colorScheme.primary,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              onSelected: (_) => viewModel.setFilter(option.status),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ColorScheme colorScheme) {
    final hasAnyGame = viewModel.totalCount > 0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasAnyGame ? Icons.filter_list_off : Icons.videogame_asset_outlined,
              size: 64,
              color: colorScheme.onSurfaceVariant.withAlpha(120),
            ),
            const SizedBox(height: 16),
            Text(
              hasAnyGame ? 'Nenhum jogo com este filtro' : 'Sua biblioteca está vazia',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              hasAnyGame
                  ? 'Nenhum jogo foi classificado como "${viewModel.selectedFilter?.label}". Selecione outro filtro ou altere o status de um jogo.'
                  : 'Pesquise jogos da IGDB e adicione-os à sua biblioteca para começar a organizar sua coleção.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onNavigateToSearch,
              icon: const Icon(Icons.search),
              label: const Text('Pesquisar Jogos'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLibraryList(BuildContext context, ColorScheme colorScheme) {
    final entries = viewModel.filteredEntries;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: entries.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final entry = entries[index];
        final game = entry.game;

        return Card(
          elevation: 1,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colorScheme.outlineVariant.withAlpha(70)),
          ),
          child: InkWell(
            onTap: () => onGameSelected(game),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Capa do Jogo
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 75,
                      height: 105,
                      child: game.coverUrl != null
                          ? Image.network(
                              game.coverUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _buildCoverPlaceholder(colorScheme),
                            )
                          : _buildCoverPlaceholder(colorScheme),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Informações e Badge de Status
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                game.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            // Menu de troca de status / remoção
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, size: 20),
                              tooltip: 'Opções',
                              onSelected: (value) {
                                if (value == 'remove') {
                                  viewModel.removeGame(game.id);
                                } else {
                                  final newStatus = GameStatus.fromString(value);
                                  viewModel.updateGameStatus(game.id, newStatus);
                                }
                              },
                              itemBuilder: (context) => [
                                ...GameStatus.values.map(
                                  (st) => PopupMenuItem(
                                    value: st.name,
                                    child: Row(
                                      children: [
                                        Icon(st.icon, size: 18, color: st.color),
                                        const SizedBox(width: 10),
                                        Text(st.label),
                                      ],
                                    ),
                                  ),
                                ),
                                const PopupMenuDivider(),
                                PopupMenuItem(
                                  value: 'remove',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline,
                                          size: 18, color: colorScheme.error),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Remover da biblioteca',
                                        style: TextStyle(color: colorScheme.error),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Badge de Status
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: entry.status.color.withAlpha(25),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: entry.status.color.withAlpha(80)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(entry.status.icon,
                                  size: 14, color: entry.status.color),
                              const SizedBox(width: 5),
                              Text(
                                entry.status.label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: entry.status.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),

                        if (entry.notes != null && entry.notes!.trim().isNotEmpty) ...[
                          Text(
                            'Nota: ${entry.notes}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],

                        Text(
                          'Ano: ${game.releaseYear}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCoverPlaceholder(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.sports_esports,
          size: 32,
          color: colorScheme.onSurfaceVariant.withAlpha(120),
        ),
      ),
    );
  }
}

class _FilterOption {
  final GameStatus? status;
  final String label;
  final IconData icon;

  const _FilterOption(this.status, this.label, this.icon);
}
