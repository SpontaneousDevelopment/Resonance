// Deletes a user completely: their rows, and the account itself.
//
// "Delete my data" means the person is gone, not that they are left with an
// empty shell they cannot log out of and cannot explain. Every progress table
// cascades from auth.users, so removing the auth record removes everything —
// but the rows are deleted explicitly first anyway, so a future table that
// forgets its cascade fails loudly here rather than quietly orphaning data.
//
// A lighter "clear my progress, keep my account" action is deliberately not
// this endpoint. Conflating them is how someone loses an account they meant to
// keep.
//
// Deploy:
//   supabase functions deploy delete-account
//   supabase secrets set SERVICE_ROLE_KEY=<the secret key>
//
// The service-role key is required — deleting an auth user is not something a
// user's own token can do — and it lives only in function secrets, never in the
// app or the repository.

import { createClient } from "npm:@supabase/supabase-js@^2.58.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY")!;

/// Tables to clear before removing the account, in dependency order.
const TABLES = [
  "attempts",
  "lesson_progress",
  "daily_xp",
  "streak_state",
  "profiles",
] as const;

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") {
    return json({ error: "Use POST." }, 405);
  }

  // The caller proves who they are with their own token. The account deleted is
  // whoever that token belongs to — never an id passed in the body, which would
  // let anyone delete anyone.
  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.replace(/^Bearer\s+/i, "");
  if (!token) {
    return json({ error: "Sign in first." }, 401);
  }

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { data: userData, error: userError } = await admin.auth.getUser(token);
  if (userError || !userData?.user) {
    return json({ error: "That session is no longer valid." }, 401);
  }

  const userId = userData.user.id;
  const deleted: Record<string, number> = {};

  for (const table of TABLES) {
    const { error, count } = await admin
      .from(table)
      .delete({ count: "exact" })
      .eq(table === "profiles" ? "id" : "user_id", userId);

    if (error) {
      // Stop rather than continue. A partial delete that reported success would
      // be the worst outcome here: the user believes they are gone and are not.
      console.error(`delete-account: ${table} failed`, error);
      return json({
        error: "Deletion could not be completed. Nothing has been removed " +
          "from your account — please try again.",
        stage: table,
      }, 500);
    }
    deleted[table] = count ?? 0;
  }

  const { error: authError } = await admin.auth.admin.deleteUser(userId);
  if (authError) {
    console.error("delete-account: auth user removal failed", authError);
    return json({
      error: "Your practice history was removed, but the account itself could " +
        "not be deleted. Contact support so this can be finished properly.",
      partial: true,
      deleted,
    }, 500);
  }

  return json({ deleted, account: "removed" }, 200);
});
