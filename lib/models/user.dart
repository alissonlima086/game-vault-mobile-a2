import 'package:supabase_flutter/supabase_flutter.dart';

/// Representação do usuario autenticado no sistema
class AppUser {
  final String id;
  final String email;
  final String? name;
  final String? avatarUrl;

  const AppUser({
    required this.id,
    required this.email,
    this.name,
    this.avatarUrl,
  });

  String get displayName {
    if (name != null && name!.trim().isNotEmpty) return name!;
    if (email.isNotEmpty) return email.split('@').first;
    return 'Jogador';
  }

  factory AppUser.fromSupabaseUser(User user) {
    final meta = user.userMetadata ?? {};
    final fullName = meta['full_name'] as String? ??
        meta['name'] as String? ??
        meta['user_name'] as String?;
    final avatar = meta['avatar_url'] as String? ?? meta['picture'] as String?;

    return AppUser(
      id: user.id,
      email: user.email ?? '',
      name: fullName,
      avatarUrl: avatar,
    );
  }
}
