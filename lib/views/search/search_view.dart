import 'package:flutter/material.dart';
import '../../models/game.dart';
import '../../viewmodels/search_viewmodel.dart';

class SearchView extends StatefulWidget {
  final SearchViewModel viewModel;
  final Function(Game game) onGameSelected;
  final String? initialQuery;

  const SearchView({
    super.key,
    required this.viewModel,
    required this.onGameSelected,
    this.initialQuery,
  });

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery ?? widget.viewModel.currentQuery);
    if (widget.initialQuery != null && widget.initialQuery!.trim().length >= 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _performSearch();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _performSearch() {
    if (_formKey.currentState?.validate() ?? false) {
      FocusScope.of(context).unfocus();
      widget.viewModel.search(_controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pesquisar'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              // Barra de pesquisa com validação de formulário
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Form(
                  key: _formKey,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _controller,
                          validator: widget.viewModel.validateQuery,
                          textInputAction: TextInputAction.search,
                          onChanged: (_) => setState(() {}),
                          onFieldSubmitted: (_) => _performSearch(),
                          decoration: InputDecoration(
                            hintText: 'Ex: Mario, Zelda, God of War, Minecraft...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _controller.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 20),
                                    tooltip: 'Limpar texto',
                                    onPressed: () {
                                      _controller.clear();
                                      widget.viewModel.clear();
                                      setState(() {});
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: colorScheme.surfaceContainerHighest.withAlpha(100),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: colorScheme.outlineVariant),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: colorScheme.outlineVariant.withAlpha(120)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: colorScheme.primary, width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: widget.viewModel.isLoading ? null : _performSearch,
                          icon: const Icon(Icons.search),
                          label: const Text('Buscar'),
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Banner informativo de modo demonstrativo (se a Edge Function não estiver no ar)
              ListenableBuilder(
                listenable: widget.viewModel,
                builder: (context, _) {
                  if (!widget.viewModel.isFallbackMode) return const SizedBox.shrink();
                  return Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer.withAlpha(100),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colorScheme.secondary.withAlpha(60)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 20, color: colorScheme.secondary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Modo Demonstrativo: Exibindo catálogo de sugestões de jogos.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // Área de Estados Reativos
              Expanded(
                child: ListenableBuilder(
                  listenable: widget.viewModel,
                  builder: (context, _) {
                    switch (widget.viewModel.state) {
                      case SearchState.initial:
                        return _buildInitialState(context, colorScheme);
                      case SearchState.loading:
                        return _buildLoadingState(context, colorScheme);
                      case SearchState.empty:
                        return _buildEmptyState(context, colorScheme);
                      case SearchState.error:
                        return _buildErrorState(context, colorScheme);
                      case SearchState.success:
                        return _buildSuccessState(context, colorScheme);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Estado 1: Inicial (Incentivo à pesquisa)
  Widget _buildInitialState(BuildContext context, ColorScheme colorScheme) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.manage_search_outlined,
              size: 80,
              color: colorScheme.primary.withAlpha(160),
            ),
            const SizedBox(height: 16),
            Text(
              'Encontre seus jogos favoritos',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Digite o nome de qualquer jogo acima para consultar o banco de dados oficial da IGDB.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildQuickTag('Mario'),
                _buildQuickTag('Zelda'),
                _buildQuickTag('God of War'),
                _buildQuickTag('Minecraft'),
                _buildQuickTag('The Witcher 3'),
                _buildQuickTag('Cyberpunk 2077'),
                _buildQuickTag('GTA V'),
                _buildQuickTag('Hades'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickTag(String label) {
    return ActionChip(
      label: Text(label),
      onPressed: () {
        _controller.text = label;
        _performSearch();
      },
    );
  }

  /// Estado 2: Carregando
  Widget _buildLoadingState(BuildContext context, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 20),
          Text(
            'Consultando a IGDB API...',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Buscando jogos no acervo...',
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// Estado 3: Lista Vazia
  Widget _buildEmptyState(BuildContext context, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_outlined,
              size: 72,
              color: colorScheme.error.withAlpha(180),
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum jogo encontrado',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Não encontramos resultados para "${widget.viewModel.currentQuery}".\nVerifique a ortografia ou tente palavras-chave diferentes.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () {
                _controller.clear();
                widget.viewModel.clear();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Limpar busca'),
            ),
            if (widget.viewModel.isFallbackMode) ...[
              const SizedBox(height: 16),
              Container(
                constraints: const BoxConstraints(maxWidth: 500),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withAlpha(100),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.outlineVariant.withAlpha(80)),
                ),
                child: Text(
                  'Dica: No momento está ativo o catálogo demonstrativo. Tente pesquisar por títulos como "Zelda", "Mario", "Witcher", "Elden Ring" ou "Cyberpunk".',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Estado 4: Erro
  Widget _buildErrorState(BuildContext context, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Card(
          color: colorScheme.errorContainer.withAlpha(70),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colorScheme.error.withAlpha(80)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 54, color: colorScheme.error),
                const SizedBox(height: 16),
                Text(
                  'Falha na Consulta',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.error,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.viewModel.errorMessage ?? 'Ocorreu um erro ao carregar os dados da IGDB.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.onErrorContainer),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _performSearch,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Estado 5: Sucesso (Resultados encontrados)
  Widget _buildSuccessState(BuildContext context, ColorScheme colorScheme) {
    final results = widget.viewModel.results;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            '${results.length} resultados para "${widget.viewModel.currentQuery}"',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: results.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final game = results[index];
              return _buildGameCard(context, game, colorScheme);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGameCard(BuildContext context, Game game, ColorScheme colorScheme) {
    return Card(
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withAlpha(70)),
      ),
      child: InkWell(
        onTap: () => widget.onGameSelected(game),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Capa do Jogo
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 80,
                  height: 110,
                  child: game.coverUrl != null
                      ? Image.network(
                          game.coverUrl!,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: colorScheme.surfaceContainerHighest,
                              child: const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return _buildCoverPlaceholder(colorScheme);
                          },
                        )
                      : _buildCoverPlaceholder(colorScheme),
                ),
              ),
              const SizedBox(width: 14),

              // Informações do Jogo
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
                        if (game.rating != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star, size: 14, color: colorScheme.primary),
                                const SizedBox(width: 3),
                                Text(
                                  game.rating!.toStringAsFixed(1),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Lançamento: ${game.releaseYear}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                    if (game.genres.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: game.genres.take(3).map((genre) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest.withAlpha(140),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              genre,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      game.shortDescription,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
