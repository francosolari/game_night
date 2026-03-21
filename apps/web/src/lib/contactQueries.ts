import { supabase } from "@/lib/supabase";

export interface SavedContact {
  id: string;
  name: string;
  phone_number: string;
  avatar_url?: string | null;
  is_app_user: boolean;
  source?: "saved" | "co-guest" | "group";
}

async function currentUserId(): Promise<string> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error("Not authenticated");
  return user.id;
}

async function currentUserPhone(): Promise<string | null> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return null;
  const { data } = await supabase
    .from("users")
    .select("phone_number")
    .eq("id", user.id)
    .single();
  return data?.phone_number ?? user.phone ?? null;
}

/** Fetch explicitly saved contacts */
export async function fetchSavedContacts(): Promise<SavedContact[]> {
  const userId = await currentUserId();
  const { data, error } = await supabase
    .from("saved_contacts")
    .select("id, name, phone_number, avatar_url, is_app_user")
    .eq("user_id", userId)
    .order("name", { ascending: true });
  if (error) throw error;
  return (data ?? []).map((c: any) => ({ ...c, source: "saved" as const }));
}

/** Fetch co-guests: people on the same event guest lists as the current user */
async function fetchCoGuests(userId: string, myPhone: string | null): Promise<SavedContact[]> {
  // Get event IDs the user is invited to or hosts
  const { data: myInvites } = await supabase
    .from("invites")
    .select("event_id")
    .eq("user_id", userId);

  const { data: hostedEvents } = await supabase
    .from("events")
    .select("id")
    .eq("host_id", userId);

  const eventIds = new Set<string>();
  for (const inv of (myInvites ?? [])) eventIds.add(inv.event_id);
  for (const ev of (hostedEvents ?? [])) eventIds.add(ev.id);

  if (eventIds.size === 0) return [];

  // Fetch all invites for those events (other people)
  const { data: coInvites } = await supabase
    .from("invites")
    .select("phone_number, display_name, user_id")
    .in("event_id", Array.from(eventIds))
    .neq("user_id", userId)
    .limit(500);

  // Dedupe by phone
  const seen = new Map<string, SavedContact>();
  for (const inv of (coInvites ?? [])) {
    const phone = inv.phone_number;
    if (!phone || phone === myPhone) continue;
    if (seen.has(phone)) continue;
    seen.set(phone, {
      id: `co-${phone}`,
      name: inv.display_name ?? phone,
      phone_number: phone,
      is_app_user: !!inv.user_id,
      source: "co-guest",
    });
  }

  return Array.from(seen.values());
}

/** Fetch group members from all groups the user owns or belongs to */
async function fetchGroupContacts(userId: string, myPhone: string | null): Promise<SavedContact[]> {
  // Groups user owns
  const { data: ownedGroups } = await supabase
    .from("groups")
    .select("id")
    .eq("owner_id", userId);

  // Groups user is a member of
  const { data: memberOf } = await supabase
    .from("group_members")
    .select("group_id")
    .eq("user_id", userId);

  const groupIds = new Set<string>();
  for (const g of (ownedGroups ?? [])) groupIds.add(g.id);
  for (const m of (memberOf ?? [])) groupIds.add(m.group_id);

  if (groupIds.size === 0) return [];

  const { data: members } = await supabase
    .from("group_members")
    .select("phone_number, display_name, user_id")
    .in("group_id", Array.from(groupIds))
    .limit(500);

  const seen = new Map<string, SavedContact>();
  for (const m of (members ?? [])) {
    const phone = m.phone_number;
    if (!phone || phone === myPhone) continue;
    // Skip self by user_id too
    if (m.user_id === userId) continue;
    if (seen.has(phone)) continue;
    seen.set(phone, {
      id: `grp-${phone}`,
      name: m.display_name ?? phone,
      phone_number: phone,
      is_app_user: !!m.user_id,
      source: "group",
    });
  }

  return Array.from(seen.values());
}

/**
 * Fetch ALL contacts: saved + co-guests + group members, deduped by phone.
 * Saved contacts take priority for name/avatar.
 */
export async function fetchAllContacts(): Promise<SavedContact[]> {
  const userId = await currentUserId();
  const myPhone = await currentUserPhone();

  const [saved, coGuests, groupMembers] = await Promise.all([
    fetchSavedContacts(),
    fetchCoGuests(userId, myPhone),
    fetchGroupContacts(userId, myPhone),
  ]);

  // Merge: saved wins over co-guest wins over group
  const byPhone = new Map<string, SavedContact>();

  // Add in reverse priority order so saved overwrites
  for (const c of groupMembers) {
    if (!byPhone.has(c.phone_number)) byPhone.set(c.phone_number, c);
  }
  for (const c of coGuests) {
    if (!byPhone.has(c.phone_number)) byPhone.set(c.phone_number, c);
    else {
      // Upgrade is_app_user if co-guest has it
      const existing = byPhone.get(c.phone_number)!;
      if (c.is_app_user && !existing.is_app_user) existing.is_app_user = true;
    }
  }
  for (const c of saved) {
    byPhone.set(c.phone_number, c); // saved always wins
  }

  return Array.from(byPhone.values()).sort((a, b) =>
    a.name.localeCompare(b.name)
  );
}

export async function fetchFrequentContacts(): Promise<SavedContact[]> {
  const userId = await currentUserId();

  const { data: hostedInvites } = await supabase
    .from("invites")
    .select("phone_number, display_name, event_id, events:event_id(host_id)")
    .limit(100);

  if (!hostedInvites) return [];

  const freq = new Map<string, { name: string; count: number }>();
  for (const inv of hostedInvites) {
    const event = inv.events as any;
    if (event?.host_id !== userId) continue;
    const phone = inv.phone_number;
    const existing = freq.get(phone);
    if (existing) {
      existing.count++;
    } else {
      freq.set(phone, { name: inv.display_name ?? phone, count: 1 });
    }
  }

  return Array.from(freq.entries())
    .sort((a, b) => b[1].count - a[1].count)
    .slice(0, 20)
    .map(([phone, v]) => ({
      id: phone,
      name: v.name,
      phone_number: phone,
      is_app_user: false,
    }));
}

export async function saveContact(contact: { name: string; phone_number: string }): Promise<void> {
  const userId = await currentUserId();
  const { error } = await supabase
    .from("saved_contacts")
    .upsert(
      { user_id: userId, name: contact.name, phone_number: contact.phone_number },
      { onConflict: "user_id,phone_number" }
    );
  if (error) throw error;
}
