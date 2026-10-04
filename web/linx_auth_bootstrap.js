// Linx Photos pairing (desktop-connect JWT) — sibling HTML form for password managers.
(function () {
  const TOKEN_KEY = 'flutter.linx_desktop_access_token_v1';
  const BASE_KEY = 'flutter.linx_api_base_url_v1';
  const DEFAULT_BASE =
    (document.documentElement.dataset.linxApiBase || 'https://linx.photos').replace(
      /\/+$/,
      '',
    );

  function readForm() {
    const form = document.getElementById('linx-auth-form');
    if (!form) return null;
    const base = form.elements.namedItem('username');
    const token = form.elements.namedItem('password');
    const apiBase = (base && base.value ? base.value : DEFAULT_BASE).trim();
    const accessToken = token && token.value ? token.value.trim() : '';
    if (!accessToken) return null;
    return { apiBase, accessToken };
  }

  function persist(session) {
    localStorage.setItem(TOKEN_KEY, session.accessToken);
    localStorage.setItem(BASE_KEY, session.apiBase);
    document.documentElement.classList.add('linx-connected');
    window.dispatchEvent(
      new CustomEvent('instalay-linx-auth', { detail: session }),
    );
  }

  function hydrateFormFromStorage() {
    const form = document.getElementById('linx-auth-form');
    if (!form) return;
    const storedBase = localStorage.getItem(BASE_KEY);
    const storedToken = localStorage.getItem(TOKEN_KEY);
    const baseEl = form.elements.namedItem('username');
    const tokenEl = form.elements.namedItem('password');
    if (baseEl && storedBase) baseEl.value = storedBase;
    if (tokenEl && storedToken) tokenEl.value = storedToken;
    if (storedToken) document.documentElement.classList.add('linx-connected');
  }

  function wireForm() {
    const form = document.getElementById('linx-auth-form');
    if (!form) return;
    form.addEventListener('submit', function (event) {
      event.preventDefault();
      const session = readForm();
      if (!session) return;
      persist(session);
    });
    const connectLink = document.getElementById('linx-open-connect');
    if (connectLink) {
      connectLink.addEventListener('click', function (event) {
        event.preventDefault();
        const base =
          (form.elements.namedItem('username') &&
            form.elements.namedItem('username').value) ||
          DEFAULT_BASE;
        const url = base.replace(/\/+$/, '') + '/account/desktop-connect';
        window.open(url, '_blank', 'noopener,noreferrer');
      });
    }
  }

  hydrateFormFromStorage();
  wireForm();

  window.instalayLinxAuth = {
    defaultApiBase: DEFAULT_BASE,
    readForm,
    persist,
    hydrateFormFromStorage,
  };
})();
