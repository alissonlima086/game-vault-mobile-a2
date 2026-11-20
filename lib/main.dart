import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/app.dart';
import 'repositories/repositories.dart';
import 'services/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Carregamento seguro das variáveis de ambiente do arquivo .env
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('Aviso: Arquivo .env não pôde ser carregado via asset: $e');
  }

  final rawUrl = (dotenv.env['SUPABASE_URL'] ??
      const String.fromEnvironment('SUPABASE_URL')).trim();
  final supabasePublishableKey = (dotenv.env['SUPABASE_PUBLISHABLE_KEY'] ??
      dotenv.env['SUPABASE_ANON_KEY'] ??
      const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY')).trim();

  // Normalização da URL do Supabase para garantir que aponte para a raiz (sem /rest/v1)
  String supabaseUrl = rawUrl;
  if (rawUrl.isNotEmpty) {
    final uri = Uri.tryParse(rawUrl);
    if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
      final portSuffix = (uri.hasPort && uri.port != 443 && uri.port != 80) ? ':${uri.port}' : '';
      supabaseUrl = '${uri.scheme}://${uri.host}$portSuffix';
    } else {
      supabaseUrl = rawUrl.replaceAll(RegExp(r'/+(rest/v1)?/?$'), '');
    }
  }

  // Inicialização do Supabase Cloud (sem expor credenciais)
  if (supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabasePublishableKey,
      );
      debugPrint('[Supabase] Inicializado com sucesso para: $supabaseUrl');
    } catch (e) {
      debugPrint('[Supabase] Erro na inicialização: $e');
    }
  } else {
    debugPrint(
      '[Supabase] SUPABASE_URL ou SUPABASE_PUBLISHABLE_KEY não configuradas no .env. '
      'Executando em modo de catálogo demonstrativo.',
    );
  }

  // Instanciação dos serviços e repositórios desacoplados por interface (MVVM)
  final authService = SupabaseAuthService();
  final igdbService = IgdbService();
  final gameRepository = SupabaseGameRepository();

  runApp(
    MobileA2App(
      igdbService: igdbService,
      gameRepository: gameRepository,
      authService: authService,
    ),
  );
}
