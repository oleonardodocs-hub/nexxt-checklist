// Controle de acesso simples: sem login individual, só uma senha única da
// equipe (ver index.html). Guarda uma flag no navegador depois que a senha
// é confirmada uma vez.

function temAcessoLiberado() {
  return localStorage.getItem("equipe_autenticada") === "1";
}

function exigirAcesso() {
  if (!temAcessoLiberado()) {
    window.location.href = "index.html";
    return false;
  }
  return true;
}

function sair() {
  localStorage.removeItem("equipe_autenticada");
  window.location.href = "index.html";
}

// Preenche a área de ações no topo (botão de sair + link para a equipe).
// Retorna false se o acesso não estiver liberado (a página já foi
// redirecionada para o login nesse caso).
function montarTopbarAcoes(elId) {
  if (!exigirAcesso()) return false;

  const el = document.getElementById(elId);
  if (el) {
    el.innerHTML = `
      <a class="btn btn-ghost" href="colaboradores.html" style="padding:4px 10px;">Equipe</a>
      <button class="btn btn-ghost" id="btn-logout" style="padding:4px 10px;">Sair</button>
    `;
    document.getElementById("btn-logout").addEventListener("click", sair);
  }
  return true;
}
