// Cliente único do Supabase, usado por todas as páginas.
// Depende de window.APP_CONFIG (ver config.example.js) e do script
// da CDN do supabase-js, que já deve ter sido carregado antes deste arquivo.

(function () {
  if (!window.APP_CONFIG || !window.APP_CONFIG.SUPABASE_URL || window.APP_CONFIG.SUPABASE_URL.includes("SEU-PROJETO")) {
    console.warn(
      "APP_CONFIG não configurado. Copie js/config.example.js para js/config.js e preencha com os dados do seu projeto Supabase."
    );
  }

  window.supabaseClient = window.supabase.createClient(
    window.APP_CONFIG.SUPABASE_URL,
    window.APP_CONFIG.SUPABASE_ANON_KEY
  );
})();
