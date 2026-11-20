import 'package:flutter/material.dart';

/// Status de jogo
enum GameStatus {
  wishlist('Quero jogar', Icons.bookmark_border, Color(0xFFF59E0B)),
  owned('Tenho', Icons.check_circle_outline, Color(0xFF10B981)),
  playing('Jogando', Icons.play_circle_outline, Color(0xFF3B82F6)),
  completed('Concluído', Icons.emoji_events_outlined, Color(0xFF8B5CF6));

  final String label;
  final IconData icon;
  final Color color;

  const GameStatus(this.label, this.icon, this.color);

  static GameStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'wishlist':
      case 'quero jogar':
        return GameStatus.wishlist;
      case 'owned':
      case 'tenho':
        return GameStatus.owned;
      case 'playing':
      case 'jogando':
        return GameStatus.playing;
      case 'completed':
      case 'concluido':
      case 'concluído':
        return GameStatus.completed;
      default:
        return GameStatus.wishlist;
    }
  }
}

/// Modelo de retorno do IGDB
class Game {
  final int id;
  final String name;
  final String? summary;
  final String? storyline;
  final String? coverUrl;
  final List<String> genres;
  final DateTime? firstReleaseDate;
  final double? rating;
  final List<String> platforms;
  final List<int> similarGames;

  const Game({
    required this.id,
    required this.name,
    this.summary,
    this.storyline,
    this.coverUrl,
    this.genres = const [],
    this.firstReleaseDate,
    this.rating,
    this.platforms = const [],
    this.similarGames = const [],
  });

  /// Formatar ano de lançamento
  String get releaseYear {
    if (firstReleaseDate == null) return 'N/A';
    return firstReleaseDate!.year.toString();
  }

  /// Descrição textual resumida para exibição em listas
  String get shortDescription {
    if (summary != null && summary!.trim().isNotEmpty) {
      if (summary!.length > 140) {
        return '${summary!.substring(0, 140)}...';
      }
      return summary!;
    }
    if (storyline != null && storyline!.trim().isNotEmpty) {
      if (storyline!.length > 140) {
        return '${storyline!.substring(0, 140)}...';
      }
      return storyline!;
    }
    return 'Sem descrição disponível.';
  }

  /// Map de Json para o modelo de Game
  factory Game.fromJson(Map<String, dynamic> json) {
    String? resolvedCoverUrl;
    if (json['coverUrl'] is String) {
      resolvedCoverUrl = json['coverUrl'] as String;
    } else if (json['cover_url'] is String) {
      resolvedCoverUrl = json['cover_url'] as String;
    } else if (json['cover'] is Map && json['cover']['url'] is String) {
      resolvedCoverUrl = json['cover']['url'] as String;
    }

    if (resolvedCoverUrl != null) {
      if (resolvedCoverUrl.startsWith('//')) {
        resolvedCoverUrl = 'https:$resolvedCoverUrl';
      }
      resolvedCoverUrl = resolvedCoverUrl.replaceFirst('t_thumb', 't_cover_big');
    }

    // Tratamento dos geneeros
    List<String> resolvedGenres = [];
    if (json['genres'] is List) {
      for (final item in json['genres'] as List) {
        if (item is String) {
          resolvedGenres.add(item);
        } else if (item is Map && item['name'] is String) {
          resolvedGenres.add(item['name'] as String);
        }
      }
    }

    // Tratamento das plataformas
    List<String> resolvedPlatforms = [];
    if (json['platforms'] is List) {
      for (final item in json['platforms'] as List) {
        if (item is String) {
          resolvedPlatforms.add(item);
        } else if (item is Map && item['name'] is String) {
          resolvedPlatforms.add(item['name'] as String);
        }
      }
    }

    // Tratamento da data de lançamento
    DateTime? releaseDate;
    if (json['first_release_date'] != null) {
      final raw = json['first_release_date'];
      if (raw is int) {
        releaseDate = DateTime.fromMillisecondsSinceEpoch(raw * 1000, isUtc: true);
      } else if (raw is String) {
        releaseDate = DateTime.tryParse(raw);
      }
    } else if (json['firstReleaseDate'] != null) {
      final raw = json['firstReleaseDate'];
      if (raw is String) {
        releaseDate = DateTime.tryParse(raw);
      } else if (raw is int) {
        releaseDate = DateTime.fromMillisecondsSinceEpoch(raw * 1000, isUtc: true);
      }
    }

    // Tratamento da nota
    double? resolvedRating;
    final rawRating = json['rating'] ?? json['total_rating'];
    if (rawRating is num) {
      resolvedRating = (rawRating.toDouble() * 10).round() / 10;
    }

    // Jogos similares
    List<int> resolvedSimilar = [];
    if (json['similar_games'] is List) {
      for (final item in json['similar_games'] as List) {
        if (item is int) resolvedSimilar.add(item);
      }
    } else if (json['similarGames'] is List) {
      for (final item in json['similarGames'] as List) {
        if (item is int) resolvedSimilar.add(item);
      }
    }

    return Game(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name'] as String? ?? 'Jogo sem título',
      summary: json['summary'] as String?,
      storyline: json['storyline'] as String?,
      coverUrl: resolvedCoverUrl,
      genres: resolvedGenres,
      firstReleaseDate: releaseDate,
      rating: resolvedRating,
      platforms: resolvedPlatforms,
      similarGames: resolvedSimilar,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'summary': summary,
      'storyline': storyline,
      'cover_url': coverUrl,
      'genres': genres,
      'first_release_date': firstReleaseDate?.toIso8601String(),
      'rating': rating,
      'platforms': platforms,
      'similar_games': similarGames,
    };
  }

  Game copyWith({
    int? id,
    String? name,
    String? summary,
    String? storyline,
    String? coverUrl,
    List<String>? genres,
    DateTime? firstReleaseDate,
    double? rating,
    List<String>? platforms,
    List<int>? similarGames,
  }) {
    return Game(
      id: id ?? this.id,
      name: name ?? this.name,
      summary: summary ?? this.summary,
      storyline: storyline ?? this.storyline,
      coverUrl: coverUrl ?? this.coverUrl,
      genres: genres ?? this.genres,
      firstReleaseDate: firstReleaseDate ?? this.firstReleaseDate,
      rating: rating ?? this.rating,
      platforms: platforms ?? this.platforms,
      similarGames: similarGames ?? this.similarGames,
    );
  }
}

/// Entrada de um jogo na biblioteca pessoal do usuário
class LibraryEntry {
  final String? id;
  final String? userId;
  final Game game;
  final GameStatus status;
  final DateTime addedAt;
  final DateTime? updatedAt;
  final String? notes;
  final int? userRating;

  const LibraryEntry({
    this.id,
    this.userId,
    required this.game,
    required this.status,
    required this.addedAt,
    this.updatedAt,
    this.notes,
    this.userRating,
  });

  LibraryEntry copyWith({
    String? id,
    String? userId,
    Game? game,
    GameStatus? status,
    DateTime? addedAt,
    DateTime? updatedAt,
    String? notes,
    int? userRating,
  }) {
    return LibraryEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      game: game ?? this.game,
      status: status ?? this.status,
      addedAt: addedAt ?? this.addedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      notes: notes ?? this.notes,
      userRating: userRating ?? this.userRating,
    );
  }

  /// Converte formato recebido do Supabase
  factory LibraryEntry.fromSupabaseJson(Map<String, dynamic> json) {
    final rawGameData = json['game_data'];
    Game parsedGame;
    if (rawGameData is Map<String, dynamic>) {
      parsedGame = Game.fromJson(rawGameData);
    } else if (rawGameData is Map) {
      parsedGame = Game.fromJson(Map<String, dynamic>.from(rawGameData));
    } else {
      parsedGame = Game(
        id: json['game_id'] as int? ?? 0,
        name: json['game_name'] as String? ?? 'Jogo sem título',
      );
    }

    return LibraryEntry(
      id: json['id']?.toString(),
      userId: json['user_id']?.toString(),
      game: parsedGame,
      status: GameStatus.fromString(json['status'] as String?),
      addedAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
      notes: json['notes'] as String?,
      userRating: json['user_rating'] as int?,
    );
  }

  /// Converte para formato a ser persistido na tabela library_entries
  Map<String, dynamic> toSupabaseJson({
    String? currentUserId,
  }) {
    final map = <String, dynamic>{
      if (id != null) 'id': id,
      'user_id': userId ?? currentUserId,
      'game_id': game.id,
      'game_name': game.name,
      'game_data': game.toJson(),
      'status': status.name,
      'notes': notes,
      'user_rating': userRating,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    return map;
  }
}
