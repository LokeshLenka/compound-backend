import "jsr:@supabase/functions-js/edge-runtime.d.ts"

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers: { "Content-Type": "application/json" } })
  }

  const authHeader = req.headers.get("Authorization")
  if (!authHeader) {
    return new Response(JSON.stringify({ error: "Missing Authorization header" }), { status: 401, headers: { "Content-Type": "application/json" } })
  }

  // Verify the caller's JWT and capture their uid.
  const { user: authUser } = await supabase.auth.getUser(authHeader.replace("Bearer ", ""))
  if (!authUser) {
    return new Response(JSON.stringify({ error: "Invalid token" }), { status: 401, headers: { "Content-Type": "application/json" } })
  }

  const userId = authUser.id

  // The function runs with the service role, so RLS does not apply.
  // Tear down owned rows in the right order, then the auth user itself.
  await supabase.from("habit_logs").delete().eq("user_id", userId)
  await supabase.from("habits").delete().eq("user_id", userId)
  await supabase.from("diary_entries").delete().eq("user_id", userId)
  await supabase.from("notes").delete().eq("user_id", userId)
  await supabase.from("projects").delete().eq("user_id", userId)
  await supabase.from("tasks").delete().eq("user_id", userId)
  await supabase.from("profiles").delete().eq("id", userId)
  await supabase.auth.admin.deleteUser(userId)

  return new Response(JSON.stringify({ ok: true }), { status: 200, headers: { "Content-Type": "application/json" } })
})