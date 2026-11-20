import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/game.dart';
import '../../viewmodels/game_details_viewmodel.dart';

class GameDetailsView extends StatefulWidget {
  final GameDetailsViewModel viewModel;
  final Function(Game game)? onSelectSimilarGame;

  const GameDetailsView({
    super.key,
    required this.viewModel,
    this.onSelectSimilarGame,
  });

  @override
  State<GameDetailsView> createState() => _GameDetailsViewState();
}

class _GameDetailsViewState extends State<GameDetailsView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.viewModel.entry?.notes);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_formKey.currentState?.validate() ?? false) {
      final success = await widget.viewModel.saveToLibrary(
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );
      if (mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.viewModel.feedbackMessage ?? 'Jogo salvo na biblioteca!',
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: widget.viewModel.selectedStatus.color,
          ),
        );
      }
    }
  }

  Future<void> _handleRemove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover da Biblioteca'),
        content: Text('Deseja remover "${widget.viewModel.game.name}" da sua biblioteca?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await widget.viewModel.removeFromLibrary();
      if (mounted && success) {
        _notesController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.viewModel.feedbackMessage ?? 'Jogo removido com sucesso.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final game = widget.viewModel.game;

    return Scaffold(
      appBar: AppBar(
        title: Text(game.name),
        leading: Navigator.canPop(context)
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Voltar',
                onPressed: () => Navigator.of(context).pushReplacementNamed('/'),
              ),
      ),
      body: ListenableBuilder(
        listenable: widget.viewModel,
        builder: (context, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Cabeçalho: Capa + Metadados Principais
                    _buildHeaderSection(context, game, colorScheme),
                    const SizedBox(height: 24),

                    // Formulário de Status e Adição à Biblioteca
                    _buildStatusForm(context, colorScheme),
                    const SizedBox(height: 24),

                    // Sinopse / Descrição
                    if (game.summary != null && game.summary!.trim().isNotEmpty) ...[
                      Text(
                        'Sinopse',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        game.summary!,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Enredo (Storyline)
                    if (game.storyline != null && game.storyline!.trim().isNotEmpty) ...[
                      Text(
                        'Enredo',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        game.storyline!,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Plataformas Disponíveis
                    if (game.platforms.isNotEmpty) ...[
                      Text(
                        'Plataformas',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: game.platforms.map((platform) {
                          return Chip(
                            avatar: const Icon(Icons.devices, size: 16),
                            label: Text(platform),
                            visualDensity: VisualDensity.compact,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Recomendações: Jogos Semelhantes (IGDB)
                    _buildSimilarGamesSection(context, colorScheme),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSimilarGamesSection(BuildContext context, ColorScheme colorScheme) {
    final vm = widget.viewModel;

    if (vm.loadingSimilar) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withAlpha(50),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text(
              'Buscando recomendações na IGDB...',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (vm.similarGames.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome, size: 20, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Jogos Semelhantes Recomendados',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: vm.similarGames.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final simGame = vm.similarGames[index];
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  if (widget.onSelectSimilarGame != null) {
                    widget.onSelectSimilarGame!(simGame);
                  } else {
                    Navigator.of(context).pushNamed(
                      '/details?id=${simGame.id}',
                      arguments: simGame,
                    );
                  }
                },
                child: Container(
                  width: 115,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colorScheme.outlineVariant.withAlpha(70)),
                    color: colorScheme.surfaceContainerHighest.withAlpha(40),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: simGame.coverUrl != null
                            ? Image.network(
                                simGame.coverUrl!,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    _buildCoverPlaceholder(colorScheme),
                              )
                            : _buildCoverPlaceholder(colorScheme),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(
                          simGame.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderSection(BuildContext context, Game game, ColorScheme colorScheme) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final formattedDate = game.firstReleaseDate != null
        ? dateFormat.format(game.firstReleaseDate!)
        : 'Data desconhecida';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 500;

        final coverWidget = Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 180, maxHeight: 250),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(60),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
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
        );

        final detailsWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              game.name,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),

            // Avaliação e Lançamento
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                if (game.rating != null) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        '${game.rating!.toStringAsFixed(1)} / 100',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ],
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 16, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text(
                      formattedDate,
                      style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Gêneros
            if (game.genres.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: game.genres.map((genre) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colorScheme.outlineVariant.withAlpha(80)),
                    ),
                    child: Text(
                      genre,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              coverWidget,
              const SizedBox(height: 16),
              detailsWidget,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            coverWidget,
            const SizedBox(width: 20),
            Expanded(child: detailsWidget),
          ],
        );
      },
    );
  }

  Widget _buildStatusForm(BuildContext context, ColorScheme colorScheme) {
    final vm = widget.viewModel;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withAlpha(80),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withAlpha(70)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Gerenciar na Biblioteca',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  if (vm.isInLibrary)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: vm.entry!.status.color.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: vm.entry!.status.color.withAlpha(90)),
                      ),
                      child: Text(
                        'Na Biblioteca',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: vm.entry!.status.color,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),

              // Seletor de Status (Segmented Button / Radio Options)
              Text(
                'Status do Jogo:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: GameStatus.values.map((status) {
                  final isSelected = vm.selectedStatus == status;
                  return ChoiceChip(
                    avatar: Icon(
                      status.icon,
                      size: 16,
                      color: isSelected ? Colors.white : status.color,
                    ),
                    label: Text(status.label),
                    selected: isSelected,
                    selectedColor: status.color,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : colorScheme.onSurface,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        vm.setSelectedStatus(status);
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // Campo opcional de Anotações Pessoais
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Anotações pessoais (opcional)',
                  hintText: 'Ex: Joguei no PC com amigos...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: colorScheme.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
              const SizedBox(height: 16),

              // Botões de Ação
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: vm.isSaving ? null : _handleSave,
                      icon: vm.isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Icon(vm.isInLibrary ? Icons.check : Icons.add),
                      label: Text(
                        vm.isInLibrary ? 'Atualizar na Biblioteca' : 'Adicionar à Biblioteca',
                      ),
                    ),
                  ),
                  if (vm.isInLibrary) ...[
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.error,
                        side: BorderSide(color: colorScheme.error.withAlpha(120)),
                      ),
                      onPressed: vm.isSaving ? null : _handleRemove,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Remover'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoverPlaceholder(ColorScheme colorScheme) {
    return Center(
      child: Icon(
        Icons.sports_esports,
        size: 48,
        color: colorScheme.onSurfaceVariant.withAlpha(120),
      ),
    );
  }
}
