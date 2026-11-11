// Funções compartilhadas de autenticação e papel do usuário.

async function requireSession() {
  const { data: { session } } = await window.supabaseClient.auth.getSession();
  if (!session) {
    window.location.href = "index.html";
    return null;
  }
  return session;
}

async function getProfile(userId) {
  const { data, error } = await window.supabaseClient
    .from("profiles")
    .select("id, nome, role")
    .eq("id", userId)
    .single();
  if (error) {
    console.error("Erro ao buscar profile:", error);
    return null;
  }
  return data;
}

async function logout() {
  await window.supabaseClient.auth.signOut();
  window.location.href = "index.html";
}

// Preenche a tag de usuário (nome + papel) presente em quase toda página.
async function mountUserTag(elId) {
  const session = await requireSession();
  if (!session) return null;
  const profile = await getProfile(session.user.id);
  const el = document.getElementById(elId);
  if (el && profile) {
    el.innerHTML = `
      ${profile.nome}
      <span class="badge-role">${profile.role === "validador" ? "Validador" : "Editor"}</span>
      <button class="btn btn-ghost" id="btn-logout" style="padding:4px 10px;">Sair</button>
    `;
    document.getElementById("btn-logout").addEventListener("click", logout);
  }
  return { session, profile };
}
