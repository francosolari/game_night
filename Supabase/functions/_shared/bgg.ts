// Shared BGG XML API2 helper for edge functions
// All BGG API calls go through here to enforce auth, rate limiting, and retry logic

import { XMLParser } from "npm:fast-xml-parser@4.3.4";

const BGG_BASE_URL = "https://boardgamegeek.com/xmlapi2";
const BGG_API_TOKEN = Deno.env.get("BGG_API_TOKEN")!;

const xmlParser = new XMLParser({
  ignoreAttributes: false,
  attributeNamePrefix: "@_",
  textNodeName: "#text",
  isArray: (_name: string, jpath: string) => {
    const tag = jpath.split(".").pop() ?? "";
    return ["item", "play", "player", "link", "rank"].includes(tag);
  },
});

/** Fetch from BGG XML API2 with Bearer auth, 202 retry, and 500/503 retry */
export async function fetchFromBGG(
  path: string,
  params: Record<string, string> = {},
  options: { max202Retries?: number; max5xxRetries?: number } = {},
): Promise<string> {
  const { max202Retries = 5, max5xxRetries = 3 } = options;

  const url = new URL(`${BGG_BASE_URL}${path}`);
  for (const [key, value] of Object.entries(params)) {
    url.searchParams.set(key, value);
  }

  let lastResponse: Response | null = null;

  // Handle 202 (queued) responses — common for collection endpoint
  for (let attempt = 0; attempt <= max202Retries; attempt++) {
    let response: Response;

    // Handle 500/503 (rate limited) responses
    for (let retryCount = 0; retryCount <= max5xxRetries; retryCount++) {
      response = await fetch(url.toString(), {
        headers: {
          Authorization: `Bearer ${BGG_API_TOKEN}`,
        },
      });

      if (response.status !== 500 && response.status !== 503) {
        break;
      }

      console.warn(`BGG returned ${response.status}, retry ${retryCount + 1}/${max5xxRetries}`);
      if (retryCount < max5xxRetries) {
        await sleep(5000); // 5s between retries per BGG recommendation
      } else {
        throw new Error(`BGG API returned ${response.status} after ${max5xxRetries} retries`);
      }
    }

    lastResponse = response!;

    if (lastResponse.status === 202) {
      console.log(`BGG returned 202 (queued), retry ${attempt + 1}/${max202Retries}`);
      if (attempt < max202Retries) {
        await sleep(3000);
        continue;
      }
      throw new Error("BGG collection request timed out (202 after max retries)");
    }

    break;
  }

  if (!lastResponse || !lastResponse.ok) {
    throw new Error(`BGG API error: ${lastResponse?.status ?? "no response"}`);
  }

  return await lastResponse.text();
}

/** Parse BGG XML response to JSON */
export function parseBGGXml(xml: string) {
  return xmlParser.parse(xml);
}

// ── Game detail parsing ──────────────────────────────────────────────

export interface ParsedGame {
  bgg_id: number;
  name: string;
  year_published: number | null;
  thumbnail_url: string | null;
  image_url: string | null;
  min_players: number;
  max_players: number;
  min_playtime: number;
  max_playtime: number;
  complexity: number;
  bgg_rating: number | null;
  description: string | null;
  categories: string[];
  mechanics: string[];
  designers: string[];
  publishers: string[];
  artists: string[];
  min_age: number | null;
  bgg_rank: number | null;
}

export interface ParsedGameRelations {
  game: ParsedGame;
  expansions: { bgg_id: number; name: string; is_inbound: boolean }[];
  families: { bgg_family_id: number; name: string }[];
}

/** Parse /xmlapi2/thing response into structured game data */
export function parseThingResponse(xml: string): ParsedGameRelations[] {
  const parsed = parseBGGXml(xml);
  const items = parsed?.items?.item;
  if (!items) return [];

  return items
    .filter((item: any) => item["@_type"] === "boardgame" || item["@_type"] === "boardgameexpansion")
    .map((item: any) => {
      const links = item.link || [];
      const stats = item.statistics?.ratings;

      const categories: string[] = [];
      const mechanics: string[] = [];
      const designers: string[] = [];
      const publishers: string[] = [];
      const artists: string[] = [];
      const expansions: { bgg_id: number; name: string; is_inbound: boolean }[] = [];
      const families: { bgg_family_id: number; name: string }[] = [];

      for (const link of links) {
        const type = link["@_type"];
        const value = link["@_value"];
        const id = parseInt(link["@_id"]);

        switch (type) {
          case "boardgamecategory": categories.push(value); break;
          case "boardgamemechanic": mechanics.push(value); break;
          case "boardgamedesigner": designers.push(value); break;
          case "boardgamepublisher": publishers.push(value); break;
          case "boardgameartist": artists.push(value); break;
          case "boardgameexpansion":
            expansions.push({ bgg_id: id, name: value, is_inbound: link["@_inbound"] === "true" });
            break;
          case "boardgamefamily":
            families.push({ bgg_family_id: id, name: value });
            break;
        }
      }

      // Extract primary name
      const names = Array.isArray(item.name) ? item.name : [item.name];
      const primaryName = names.find((n: any) => n["@_type"] === "primary")?.["@_value"] ?? "";

      // Extract BGG rank
      let bggRank: number | null = null;
      const ranks = stats?.ranks?.rank;
      if (ranks) {
        const boardgameRank = ranks.find((r: any) => r["@_name"] === "boardgame");
        const rv = boardgameRank?.["@_value"];
        if (rv && rv !== "Not Ranked") bggRank = parseInt(rv);
      }

      const avgRating = parseFloat(stats?.average?.["@_value"] ?? "0");

      const game: ParsedGame = {
        bgg_id: parseInt(item["@_id"]),
        name: primaryName,
        year_published: intOrNull(item.yearpublished?.["@_value"]),
        thumbnail_url: item.thumbnail ?? null,
        image_url: item.image ?? null,
        min_players: parseInt(item.minplayers?.["@_value"] ?? "1") || 1,
        max_players: parseInt(item.maxplayers?.["@_value"] ?? "4") || 4,
        min_playtime: parseInt(item.minplaytime?.["@_value"] ?? "30") || 30,
        max_playtime: parseInt(item.maxplaytime?.["@_value"] ?? "60") || 60,
        complexity: parseFloat(stats?.averageweight?.["@_value"] ?? "0") || 0,
        bgg_rating: avgRating > 0 ? avgRating : null,
        description: item.description ?? null,
        categories,
        mechanics,
        designers,
        publishers,
        artists,
        min_age: intOrNull(item.minage?.["@_value"]),
        bgg_rank: bggRank,
      };

      return { game, expansions, families };
    });
}

// ── Search result parsing ────────────────────────────────────────────

export interface ParsedSearchResult {
  bgg_id: number;
  name: string;
  year_published: number | null;
}

/** Parse /xmlapi2/search response */
export function parseSearchResponse(xml: string): ParsedSearchResult[] {
  const parsed = parseBGGXml(xml);
  const items = parsed?.items?.item;
  if (!items) return [];

  return items.map((item: any) => {
    const names = Array.isArray(item.name) ? item.name : [item.name];
    const primaryName = names.find((n: any) => n["@_type"] === "primary")?.["@_value"] ??
                        names[0]?.["@_value"] ?? "";

    return {
      bgg_id: parseInt(item["@_id"]),
      name: primaryName,
      year_published: intOrNull(item.yearpublished?.["@_value"]),
    };
  });
}

// ── Hot games parsing ────────────────────────────────────────────────

export interface ParsedHotGame {
  bgg_id: number;
  name: string;
  year_published: number | null;
  thumbnail_url: string | null;
  rank: number;
}

/** Parse /xmlapi2/hot response */
export function parseHotResponse(xml: string): ParsedHotGame[] {
  const parsed = parseBGGXml(xml);
  const items = parsed?.items?.item;
  if (!items) return [];

  return items.map((item: any) => ({
    bgg_id: parseInt(item["@_id"]),
    name: item.name?.["@_value"] ?? "",
    year_published: intOrNull(item.yearpublished?.["@_value"]),
    thumbnail_url: item.thumbnail?.["@_value"] ?? null,
    rank: parseInt(item["@_rank"]) || 0,
  }));
}

// ── Collection parsing ───────────────────────────────────────────────

export interface ParsedCollectionItem {
  bgg_id: number;
  name: string;
  year_published: number | null;
  thumbnail_url: string | null;
  image_url: string | null;
  num_plays: number;
  user_rating: number | null;
}

/** Parse /xmlapi2/collection response */
export function parseCollectionResponse(xml: string): ParsedCollectionItem[] {
  const parsed = parseBGGXml(xml);
  const items = parsed?.items?.item;
  if (!items) return [];

  return items.map((item: any) => {
    const userRating = parseFloat(item.stats?.rating?.["@_value"] ?? "0");
    return {
      bgg_id: parseInt(item["@_objectid"]),
      name: typeof item.name === "string" ? item.name : item.name?.["#text"] ?? "",
      year_published: intOrNull(item.yearpublished),
      thumbnail_url: item.thumbnail ?? null,
      image_url: item.image ?? null,
      num_plays: parseInt(item.numplays ?? "0") || 0,
      user_rating: userRating > 0 ? userRating : null,
    };
  });
}

// ── Plays parsing ────────────────────────────────────────────────────

export interface ParsedPlay {
  bgg_play_id: number;
  bgg_game_id: number;
  game_name: string;
  date: string;
  quantity: number;
  length_minutes: number;
  incomplete: boolean;
  location: string | null;
  players: ParsedPlayer[];
}

export interface ParsedPlayer {
  username: string | null;
  bgg_user_id: number | null;
  name: string;
  start_position: string | null;
  color: string | null;
  score: number | null;
  new_to_game: boolean;
  bgg_rating: number | null;
  win: boolean;
}

/** Parse /xmlapi2/plays response */
export function parsePlaysResponse(xml: string): { plays: ParsedPlay[]; total: number } {
  const parsed = parseBGGXml(xml);
  const playsNode = parsed?.plays;
  if (!playsNode) return { plays: [], total: 0 };

  const total = parseInt(playsNode["@_total"] ?? "0");
  const playItems = playsNode.play;
  if (!playItems) return { plays: [], total };

  const plays: ParsedPlay[] = playItems.map((play: any) => {
    const item = play.item;
    const playerList = play.players?.player || [];

    return {
      bgg_play_id: parseInt(play["@_id"]),
      bgg_game_id: parseInt(item?.["@_objectid"] ?? "0"),
      game_name: item?.["@_name"] ?? "",
      date: play["@_date"] ?? "",
      quantity: parseInt(play["@_quantity"] ?? "1") || 1,
      length_minutes: parseInt(play["@_length"] ?? "0") || 0,
      incomplete: play["@_incomplete"] === "1",
      location: play["@_location"] || null,
      players: playerList.map((p: any) => ({
        username: p["@_username"] || null,
        bgg_user_id: intOrNull(p["@_userid"]),
        name: p["@_name"] ?? "Unknown",
        start_position: p["@_startposition"] || null,
        color: p["@_color"] || null,
        score: intOrNull(p["@_score"]),
        new_to_game: p["@_new"] === "1",
        bgg_rating: floatOrNull(p["@_rating"]),
        win: p["@_win"] === "1",
      })),
    };
  });

  return { plays, total };
}

// ── Helpers ──────────────────────────────────────────────────────────

function intOrNull(val: string | undefined | null): number | null {
  if (!val) return null;
  const n = parseInt(val);
  return isNaN(n) ? null : n;
}

function floatOrNull(val: string | undefined | null): number | null {
  if (!val || val === "N/A") return null;
  const n = parseFloat(val);
  return isNaN(n) ? null : n;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
