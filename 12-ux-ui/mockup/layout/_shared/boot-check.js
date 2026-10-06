// Aviso cuando la pagina no termina de cargar.
// Antes, si faltaba el runtime, quedaba una pantalla a medias sin explicacion.
// Todo se sirve desde _shared/vendor, asi que esto solo deberia verse si falta un archivo.
(function () {
  function banner(texto) {
    if (document.querySelector('.ts-boot-error')) return;
    var box = document.createElement('div');
    box.className = 'ts-boot-error';
    box.setAttribute('role', 'alert');
    box.textContent = texto;
    box.style.cssText = 'position:fixed;left:0;right:0;top:0;z-index:9999;padding:14px 20px;' +
      'background:#7F1D1D;color:#fff;font:700 16px/1.45 system-ui,sans-serif;text-align:center;';
    (document.body || document.documentElement).appendChild(box);
  }

  function check() {
    if (typeof window.React === 'undefined') {
      banner('Esta pagina no cargo por completo: falta el runtime en _shared/vendor/. Revisa que la carpeta este completa y recarga.');
      return;
    }
    if (typeof window.lucide === 'undefined') {
      banner('Los iconos no cargaron: falta _shared/vendor/lucide.min.js. El resto de la pagina funciona.');
    }
  }

  function start() { setTimeout(check, 6000); }
  if (document.readyState === 'loading') { document.addEventListener('DOMContentLoaded', start); } else { start(); }
})();
