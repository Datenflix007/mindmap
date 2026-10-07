(function(){
  const cfg = window.APP_CONFIG || {};
  const configured = cfg.SUPABASE_URL && !cfg.SUPABASE_URL.includes('DEIN-PROJEKT') && cfg.SUPABASE_PUBLISHABLE_KEY && !cfg.SUPABASE_PUBLISHABLE_KEY.includes('DEIN_KEY');
  window.APP_CONFIGURED = !!configured;
  window.db = configured ? supabase.createClient(cfg.SUPABASE_URL, cfg.SUPABASE_PUBLISHABLE_KEY, { auth: { persistSession:false, autoRefreshToken:false, detectSessionInUrl:false } }) : null;
})();
