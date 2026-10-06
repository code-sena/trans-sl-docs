// Sesión del mockup: quién entró y qué puede ver.
// Espejo de frontendTS/src/shared/utils/adminAccess.ts: el rol se decide por el correo.
// Cuando exista el backend, esto lo reemplaza el rol que devuelva la API (UX-02).
(function () {
  var ADMIN_EMAILS = ['aleosea777@gmail.com'];

  function normalize(email) { return (email || '').trim().toLowerCase(); }

  window.__tsAdminEmails = ADMIN_EMAILS;
  window.__tsIsAdmin = function (email) { return ADMIN_EMAILS.indexOf(normalize(email)) >= 0; };
  window.__tsSession = function () {
    try { return JSON.parse(localStorage.getItem('ts-session') || 'null'); } catch (e) { return null; }
  };
  window.__tsSignIn = function (email) {
    try { localStorage.setItem('ts-session', JSON.stringify({ email: normalize(email) })); } catch (e) {}
  };
  window.__tsSignOut = function () {
    try { localStorage.removeItem('ts-session'); } catch (e) {}
  };
  // A dónde va el login según el correo.
  window.__tsHomeFor = function (email) {
    return window.__tsIsAdmin(email) ? '../view-usage-statistics/index.html' : '../translate-signs/index.html';
  };

  var session = window.__tsSession();
  window.__tsUserEmail = session ? session.email : '';
  window.__tsRole = session && window.__tsIsAdmin(session.email) ? 'admin' : 'user';

  function denied(titulo, mensaje, destino, etiqueta) {
    document.documentElement.className += ' ts-denied';
    var style = document.createElement('style');
    style.textContent = 'html.ts-denied body > *:not(.ts-denied-card){display:none!important}' +
      '.ts-denied-card{max-width:520px;margin:15vh auto;padding:32px;border-radius:24px;background:#fff;' +
      'border:1px solid #EEE9FA;box-shadow:0 20px 46px rgba(30,20,60,.12);text-align:center;' +
      "font-family:'Nunito Sans',system-ui,sans-serif;color:#1F2937}" +
      '.ts-denied-card h1{font-size:24px;font-weight:800;margin:0 0 10px}' +
      '.ts-denied-card p{font-size:16px;line-height:1.55;color:#4B5563;margin:0 0 24px}' +
      '.ts-denied-card a{display:inline-flex;align-items:center;justify-content:center;min-height:48px;' +
      'padding:0 24px;border-radius:12px;background:linear-gradient(135deg,#7E5AD0,#6D28D9);color:#fff;' +
      'font-size:17px;font-weight:700;text-decoration:none}' +
      '.ts-denied-card small{display:block;margin-top:16px;font-size:14px;color:#6B7280}';
    document.head.appendChild(style);

    function render() {
      if (document.querySelector('.ts-denied-card')) return;
      var card = document.createElement('div');
      card.className = 'ts-denied-card';
      card.setAttribute('role', 'alert');
      var h = document.createElement('h1'); h.textContent = titulo;
      var p = document.createElement('p'); p.textContent = mensaje;
      var a = document.createElement('a'); a.href = destino; a.textContent = etiqueta;
      var s = document.createElement('small');
      s.textContent = window.__tsUserEmail ? 'Sesión: ' + window.__tsUserEmail : '';
      card.appendChild(h); card.appendChild(p); card.appendChild(a); card.appendChild(s);
      document.body.appendChild(card);
    }
    if (document.readyState === 'loading') { document.addEventListener('DOMContentLoaded', render); } else { render(); }
  }

  // Cada página declara para quién es. Sin sesión iniciada se muestra tal cual,
  // para poder revisar el diseño; con sesión, manda el rol del correo.
  window.__tsGuardRole = function (required) {
    if (!session) { window.__tsRole = required; return; }
    if (window.__tsRole === required) return;
    if (required === 'admin') {
      denied('Esta sección es solo para administradores',
        'Tu cuenta no tiene permiso para ver las estadísticas ni el panel de administración.',
        '../translate-signs/index.html', 'Ir al traductor');
    } else {
      denied('Esta sección es para usuarios',
        'Entraste con una cuenta de administrador, que solo tiene acceso a Estadísticas y Administración.',
        '../view-usage-statistics/index.html', 'Ir a Estadísticas');
    }
  };

  // "Cerrar sesión" termina la sesión del mockup.
  document.addEventListener('click', function (ev) {
    var link = ev.target && ev.target.closest ? ev.target.closest('a[href*="sign-in"]') : null;
    if (link && /cerrar sesi/i.test(link.textContent || '')) window.__tsSignOut();
  });
})();
