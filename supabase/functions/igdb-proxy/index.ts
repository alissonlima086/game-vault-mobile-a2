// Supabase Edge Function: igdb-proxy
// Intermediador seguro para a IGDB API v4 utilizando credenciais Twitch (Client Credentials)
// Secrets esperados em Deno.env: TWITCH_CLIENT_ID e TWITCH_CLIENT_SECRET

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
};

interface TokenCache {
  accessToken: string;
  expiresAt: number; // timestamp em ms
}

let tokenCache: TokenCache | null = null;

/**
 * Obtém o token de acesso da Twitch via OAuth2 Client Credentials.
 * Reutiliza o token em memória enquanto estiver válido (com margem de segurança de 60s).
 */
async function getTwitchAccessToken(clientId: string, clientSecret: string): Promise<string> {
  const now = Date.now();
  if (tokenCache && now < tokenCache.expiresAt - 60000) {
    return tokenCache.accessToken;
  }

  const tokenUrl = "https://id.twitch.tv/oauth2/token";
  const params = new URLSearchParams({
    client_id: clientId,
    client_secret: clientSecret,
    grant_type: "client_credentials",
  });

  const response = await fetch(tokenUrl, {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: params.toString(),
  });

  if (!response.ok) {
    const errorText = await response.text();
    console.error(`Falha na autenticação Twitch (HTTP ${response.status})`);
    throw new Error(`Falha na autenticação com a Twitch: status ${response.status}`);
  }

  const data = await response.json();
  const accessToken = data.access_token;
  const expiresIn = data.expires_in; // segundos

  if (!accessToken || typeof accessToken !== "string") {
    throw new Error("Resposta de autenticação da Twitch não contém access_token válido.");
  }

  tokenCache = {
    accessToken,
    expiresAt: now + expiresIn * 1000,
  };

  return accessToken;
}

/**
 * Sanitiza o termo de busca para evitar injeção na sintaxe APICalypse da IGDB.
 */
function sanitizeSearchQuery(query: string): string {
  return query
    .replace(/\\/g, "\\\\")
    .replace(/"/g, '\\"')
    .replace(/;/g, "")
    .trim();
}

/**
 * Normaliza a URL da capa retornada pela IGDB para formato https com alta resolução (t_cover_big).
 */
function formatCoverUrl(rawUrl?: string): string | null {
  if (!rawUrl) return null;
  let formatted = rawUrl;
  if (formatted.startsWith("//")) {
    formatted = "https:" + formatted;
  }
  return formatted.replace("t_thumb", "t_cover_big");
}

serve(async (req: Request) => {
  // Tratamento de requisições de preflight CORS
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const clientId = Deno.env.get("TWITCH_CLIENT_ID");
    const clientSecret = Deno.env.get("TWITCH_CLIENT_SECRET");

    if (!clientId || !clientSecret) {
      console.error("Secrets TWITCH_CLIENT_ID e/ou TWITCH_CLIENT_SECRET ausentes no servidor.");
      return new Response(
        JSON.stringify({
          error: "Credenciais de serviço não configuradas no servidor.",
        }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    let searchQuery = "";
    let ids: number[] = [];
    let limit = 20;

    if (req.method === "POST") {
      try {
        const body = await req.json();
        searchQuery = body.query || body.search || "";
        if (Array.isArray(body.ids)) {
          ids = body.ids
            .map((v: unknown) => (typeof v === "number" ? v : parseInt(String(v), 10)))
            .filter((n: number) => !isNaN(n) && n > 0);
        }
        if (typeof body.limit === "number") {
          limit = Math.min(Math.max(body.limit, 1), 50);
        }
      } catch {
        return new Response(
          JSON.stringify({ error: "Corpo da requisição inválido. JSON esperado." }),
          {
            status: 400,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      }
    } else if (req.method === "GET") {
      const url = new URL(req.url);
      searchQuery = url.searchParams.get("query") || url.searchParams.get("search") || "";
      const idsParam = url.searchParams.get("ids");
      if (idsParam) {
        ids = idsParam
          .split(",")
          .map((s) => parseInt(s.trim(), 10))
          .filter((n) => !isNaN(n) && n > 0);
      }
      const limitParam = url.searchParams.get("limit");
      if (limitParam) {
        const parsedLimit = parseInt(limitParam, 10);
        if (!isNaN(parsedLimit)) {
          limit = Math.min(Math.max(parsedLimit, 1), 50);
        }
      }
    } else {
      return new Response(
        JSON.stringify({ error: "Método HTTP não permitido." }),
        {
          status: 405,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Validação de entrada: ou lista de IDs ou busca textual
    let apicalypseBody = "";
    if (ids.length > 0) {
      const limitedIds = ids.slice(0, 20);
      apicalypseBody = `
        where id = (${limitedIds.join(",")});
        fields id,name,summary,storyline,cover.url,genres.name,first_release_date,rating,total_rating,platforms.name,similar_games;
        limit ${limit};
      `.trim();
    } else {
      const trimmed = searchQuery.trim();
      if (!trimmed || trimmed.length < 2) {
        return new Response(
          JSON.stringify({ error: "O termo de pesquisa deve ter pelo menos 2 caracteres." }),
          {
            status: 400,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      }

      if (trimmed.length > 100) {
        return new Response(
          JSON.stringify({ error: "O termo de pesquisa não pode exceder 100 caracteres." }),
          {
            status: 400,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      }

      const sanitized = sanitizeSearchQuery(trimmed);
      const fetchLimit = Math.min(Math.max(limit * 2, 40), 100);
      apicalypseBody = `
        search "${sanitized}";
        fields id,name,summary,storyline,cover.url,genres.name,first_release_date,rating,total_rating,platforms.name,similar_games,category,version_parent;
        limit ${fetchLimit};
      `.trim();
    }

    // Obtenção do token Twitch
    const accessToken = await getTwitchAccessToken(clientId, clientSecret);

    // Consulta à IGDB API v4
    const igdbResponse = await fetch("https://api.igdb.com/v4/games", {
      method: "POST",
      headers: {
        "Client-ID": clientId,
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "text/plain",
      },
      body: apicalypseBody,
    });

    if (!igdbResponse.ok) {
      const errorText = await igdbResponse.text();
      console.error(`Erro na consulta IGDB (HTTP ${igdbResponse.status}): ${errorText}`);
      return new Response(
        JSON.stringify({
          error: "Falha ao consultar a base de dados da IGDB.",
          details: igdbResponse.statusText,
        }),
        {
          status: 502,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const rawGames = await igdbResponse.json();

    // Sanitização e projeção de dados segura para o cliente
    const formattedGames = Array.isArray(rawGames)
      ? rawGames
          .filter((game: any) => game && game.name && game.category !== 5 && game.category !== 12 && game.category !== 14)
          .sort((a: any, b: any) => {
            // 1. Prioriza jogos com capa
            const aHasCover = a.cover?.url ? 1 : 0;
            const bHasCover = b.cover?.url ? 1 : 0;
            if (aHasCover !== bHasCover) return bHasCover - aHasCover;

            // 2. Prioriza jogos principais (0), remakes (8), remasters (9), expansões (4, 2)
            const mainCategories = [0, 8, 9, 10, 4, 2, 3];
            const aIsMain = mainCategories.includes(a.category) ? 1 : 0;
            const bIsMain = mainCategories.includes(b.category) ? 1 : 0;
            if (aIsMain !== bIsMain) return bIsMain - aIsMain;

            // 3. Prioriza jogos avaliados / com nota
            const aRating = a.total_rating ?? a.rating ?? 0;
            const bRating = b.total_rating ?? b.rating ?? 0;
            return bRating - aRating;
          })
          .slice(0, limit)
          .map((game: any) => ({
            id: game.id,
            name: game.name || "Jogo sem título",
            summary: game.summary || null,
            storyline: game.storyline || null,
            cover_url: formatCoverUrl(game.cover?.url),
            genres: Array.isArray(game.genres)
              ? game.genres.map((g: any) => g.name).filter(Boolean)
              : [],
            first_release_date: game.first_release_date
              ? new Date(game.first_release_date * 1000).toISOString()
              : null,
            rating:
              typeof game.rating === "number"
                ? Math.round(game.rating * 10) / 10
                : typeof game.total_rating === "number"
                ? Math.round(game.total_rating * 10) / 10
                : null,
            platforms: Array.isArray(game.platforms)
              ? game.platforms.map((p: any) => p.name).filter(Boolean)
              : [],
            similar_games: Array.isArray(game.similar_games)
              ? game.similar_games.filter((id: any) => typeof id === "number")
              : [],
          }))
      : [];

    return new Response(JSON.stringify(formattedGames), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error: any) {
    console.error("Erro interno no igdb-proxy:", error);
    return new Response(
      JSON.stringify({
        error: "Erro interno no servidor de consulta.",
        message: error?.message || "Erro desconhecido",
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
