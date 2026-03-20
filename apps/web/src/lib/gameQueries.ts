import { supabase } from "@/lib/supabase";
import type { Game, GameLibraryEntry, GameCategory } from "@/lib/types";

const LIBRARY_GAME_SELECT = "id,owner_id,bgg_id,name,year_published,thumbnail_url,image_url,min_players,max_players,recommended_players,min_playtime,max_playtime,complexity,bgg_rating";

function isMissingRelationError(error: any): boolean {
  const code = error?.code;
  const message = String(error?.message ?? "");
  return code === "42P01" || code === "42703" || code === "PGRST200" || message.includes("does not exist") || message.includes("schema cache");
}

// ─── Library ───

export async function fetchGameLibrary(userId?: string): Promise<GameLibraryEntry[]> {
  const currentUserId = userId ?? (await supabase.auth.getUser()).data.user?.id;
  if (!currentUserId) throw new Error("Not authenticated");

  const { data, error } = await supabase
    .from("game_library")
    .select(`id,user_id,game_id,category_id,rating,play_count,added_at,notes,game:games(${LIBRARY_GAME_SELECT})`)
    .eq("user_id", currentUserId)
    .order("added_at", { ascending: false });

  if (error) throw error;

  return (data ?? []).map((entry: any) => ({
    ...entry,
    game: Array.isArray(entry.game) ? (entry.game[0] ?? null) : (entry.game ?? null),
  })) as unknown as GameLibraryEntry[];
}

export async function fetchGameById(id: string): Promise<Game> {
  const { data, error } = await supabase
    .from("games")
    .select("*")
    .eq("id", id)
    .single();

  if (error) throw error;
  return data as Game;
}

export async function addGameToLibrary(gameId: string, categoryId?: string | null): Promise<void> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error("Not authenticated");

  const { error } = await supabase.from("game_library").insert({
    user_id: user.id,
    game_id: gameId,
    category_id: categoryId || null,
  });
  if (error) throw error;
}

export async function removeFromLibrary(entryId: string): Promise<void> {
  const { error } = await supabase.from("game_library").delete().eq("id", entryId);
  if (error) throw error;
}

export async function updateGame(game: Partial<Game> & { id: string }): Promise<void> {
  const { error } = await supabase.from("games").update({
    name: game.name,
    year_published: game.year_published,
    min_players: game.min_players,
    max_players: game.max_players,
    recommended_players: game.recommended_players,
    min_playtime: game.min_playtime,
    max_playtime: game.max_playtime,
    complexity: game.complexity,
    bgg_rating: game.bgg_rating,
    description: game.description,
    categories: game.categories,
    mechanics: game.mechanics,
    designers: game.designers,
    publishers: game.publishers,
    artists: game.artists,
    min_age: game.min_age,
    image_url: game.image_url,
  }).eq("id", game.id);
  if (error) throw error;
}

// ─── Relations ───

export async function fetchExpansions(gameId: string): Promise<Game[]> {
  const { data, error } = await supabase
    .from("game_expansions")
    .select("expansion:games!game_expansions_expansion_id_fkey(*)")
    .eq("base_game_id", gameId);

  if (error) {
    if (isMissingRelationError(error)) return [];
    throw error;
  }
  return (data ?? []).map((d: any) => d.expansion).filter(Boolean) as Game[];
}

export async function fetchBaseGame(gameId: string): Promise<Game | null> {
  const { data, error } = await supabase
    .from("game_expansions")
    .select("base:games!game_expansions_base_game_id_fkey(*)")
    .eq("expansion_id", gameId)
    .limit(1);

  if (error) {
    if (isMissingRelationError(error)) return null;
    throw error;
  }
  if (data && data.length > 0) return (data[0] as any).base as Game;
  return null;
}

export async function fetchFamilyMembers(gameId: string): Promise<{ family: { id: string; name: string; bgg_family_id: number }; games: Game[] }[]> {
  const { data: memberRows, error: mErr } = await supabase
    .from("game_family_members")
    .select("family_id")
    .eq("game_id", gameId);

  if (mErr) {
    if (isMissingRelationError(mErr)) return [];
    throw mErr;
  }
  if (!memberRows || memberRows.length === 0) return [];

  const familyIds = [...new Set(memberRows.map((r: any) => r.family_id))];

  const { data: families, error: fErr } = await supabase
    .from("game_families")
    .select("*")
    .in("id", familyIds);

  if (fErr) {
    if (isMissingRelationError(fErr)) return [];
    throw fErr;
  }

  const { data: members, error: gmErr } = await supabase
    .from("game_family_members")
    .select("family_id,game:games(*)")
    .in("family_id", familyIds);

  if (gmErr) {
    if (isMissingRelationError(gmErr)) return [];
    throw gmErr;
  }

  const gamesByFamily = new Map<string, Game[]>();
  for (const member of members ?? []) {
    const familyId = (member as any).family_id as string;
    const game = (member as any).game as Game | null;
    if (!game) continue;
    if (!gamesByFamily.has(familyId)) gamesByFamily.set(familyId, []);
    gamesByFamily.get(familyId)!.push(game);
  }

  const results: { family: any; games: Game[] }[] = (families ?? []).map((fam: any) => ({
    family: fam,
    games: gamesByFamily.get(fam.id) ?? [],
  }));

  return results;
}

export async function fetchGamesByCreator(name: string, role: "designer" | "publisher"): Promise<Game[]> {
  const column = role === "designer" ? "designers" : "publishers";
  const { data, error } = await supabase
    .from("games")
    .select("*")
    .contains(column, [name]);

  if (error) throw error;
  return (data ?? []) as Game[];
}

// ─── Categories ───

export async function fetchCategories(userId?: string): Promise<GameCategory[]> {
  const currentUserId = userId ?? (await supabase.auth.getUser()).data.user?.id;
  if (!currentUserId) throw new Error("Not authenticated");

  const { data, error } = await supabase
    .from("game_categories")
    .select("*")
    .eq("user_id", currentUserId)
    .order("sort_order", { ascending: true });

  if (error) throw error;
  return (data ?? []) as GameCategory[];
}

export async function createCategory(name: string, icon?: string | null): Promise<void> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error("Not authenticated");

  const { error } = await supabase.from("game_categories").insert({
    user_id: user.id,
    name,
    icon: icon || null,
  });
  if (error) throw error;
}

// ─── BGG Search (via direct XML API proxy) ───

export interface BGGSearchResult {
  id: number;
  name: string;
  yearPublished?: number | null;
  thumbnailUrl?: string | null;
}

export async function searchBGG(query: string): Promise<BGGSearchResult[]> {
  if (!query.trim()) return [];
  const res = await fetch(`https://boardgamegeek.com/xmlapi2/search?query=${encodeURIComponent(query)}&type=boardgame`);
  const text = await res.text();
  const parser = new DOMParser();
  const doc = parser.parseFromString(text, "text/xml");
  const items = doc.querySelectorAll("item");
  const results: BGGSearchResult[] = [];
  items.forEach(item => {
    const id = parseInt(item.getAttribute("id") || "0");
    const nameEl = item.querySelector("name");
    const name = nameEl?.getAttribute("value") || "";
    const yearEl = item.querySelector("yearpublished");
    const year = yearEl ? parseInt(yearEl.getAttribute("value") || "0") || null : null;
    if (id && name) results.push({ id, name, yearPublished: year });
  });
  return results;
}

export async function fetchBGGGameDetail(bggId: number): Promise<Partial<Game> | null> {
  const res = await fetch(`https://boardgamegeek.com/xmlapi2/thing?id=${bggId}&stats=1`);
  const text = await res.text();
  const parser = new DOMParser();
  const doc = parser.parseFromString(text, "text/xml");
  const item = doc.querySelector("item");
  if (!item) return null;

  const getName = (type: string) => {
    const el = item.querySelector(`name[type="${type}"]`);
    return el?.getAttribute("value") || "";
  };

  const getVal = (sel: string) => {
    const el = item.querySelector(sel);
    return el?.getAttribute("value") || el?.textContent || "";
  };

  const getLinks = (type: string) => {
    const els = item.querySelectorAll(`link[type="${type}"]`);
    return Array.from(els).map(e => e.getAttribute("value") || "").filter(Boolean);
  };

  const minP = parseInt(getVal("minplayers")) || 1;
  const maxP = parseInt(getVal("maxplayers")) || 4;
  const minT = parseInt(getVal("minplaytime")) || 30;
  const maxT = parseInt(getVal("maxplaytime")) || 60;
  const weight = parseFloat(getVal("statistics ratings averageweight")) || 2.5;
  const rating = parseFloat(getVal("statistics ratings average")) || undefined;
  const rank = parseInt(item.querySelector("rank[name='boardgame']")?.getAttribute("value") || "0") || undefined;

  // Recommended players from poll
  const recPlayers: number[] = [];
  const pollItems = item.querySelectorAll("poll[name='suggested_numplayers'] results");
  pollItems.forEach(r => {
    const np = parseInt(r.getAttribute("numplayers") || "0");
    const bestVotes = parseInt(r.querySelector("result[value='Best']")?.getAttribute("numvotes") || "0");
    const recVotes = parseInt(r.querySelector("result[value='Recommended']")?.getAttribute("numvotes") || "0");
    const notRecVotes = parseInt(r.querySelector("result[value='Not Recommended']")?.getAttribute("numvotes") || "0");
    if (np && (bestVotes + recVotes) > notRecVotes) recPlayers.push(np);
  });

  return {
    bgg_id: bggId,
    name: getName("primary"),
    year_published: parseInt(getVal("yearpublished")) || null,
    thumbnail_url: item.querySelector("thumbnail")?.textContent || null,
    image_url: item.querySelector("image")?.textContent || null,
    min_players: minP,
    max_players: maxP,
    recommended_players: recPlayers.length > 0 ? recPlayers : null,
    min_playtime: minT,
    max_playtime: maxT,
    complexity: weight,
    bgg_rating: rating ?? null,
    bgg_rank: rank ?? null,
    min_age: parseInt(getVal("minage")) || null,
    description: item.querySelector("description")?.textContent?.replace(/&#10;/g, "\n").slice(0, 2000) || null,
    categories: getLinks("boardgamecategory"),
    mechanics: getLinks("boardgamemechanic"),
    designers: getLinks("boardgamedesigner"),
    publishers: getLinks("boardgamepublisher").slice(0, 5),
    artists: getLinks("boardgameartist"),
  };
}

export async function upsertGameFromBGG(bggDetail: Partial<Game>): Promise<Game> {
  // Check if game already exists by bgg_id
  const { data: existing } = await supabase
    .from("games")
    .select("*")
    .eq("bgg_id", bggDetail.bgg_id!)
    .limit(1);

  if (existing && existing.length > 0) {
    // Update existing
    const { data, error } = await supabase
      .from("games")
      .update(bggDetail)
      .eq("id", existing[0].id)
      .select()
      .single();
    if (error) throw error;
    return data as Game;
  }

  // Insert new
  const { data, error } = await supabase
    .from("games")
    .insert(bggDetail)
    .select()
    .single();
  if (error) throw error;
  return data as Game;
}
