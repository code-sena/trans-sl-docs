// Capa de accesibilidad: nombres accesibles y atributos que el diseño exportado no trae.
// Corre después de cada render del runtime (observa el DOM), sin tocar el diseño.
(function () {
  var ICON_LABELS = {
    'eye': 'Mostrar contraseña', 'eye-off': 'Ocultar contraseña', 'x': 'Cerrar', 'arrow-left': 'Volver',
    'copy': 'Copiar', 'volume-2': 'Escuchar', 'trash-2': 'Eliminar', 'rotate-ccw': 'Repetir',
    'chevron-left': 'Anterior', 'chevron-right': 'Siguiente', 'moon': 'Activar tema oscuro', 'sun': 'Activar tema claro',
    'globe': 'Idioma', 'search': 'Buscar', 'camera': 'Cámara', 'play': 'Reproducir', 'send': 'Enviar', 'check': 'Confirmar'
  };
  function hasText(el) { return (el.textContent || '').replace(/\s+/g, '') !== ''; }

  function apply() {
    var doc = document;
    if (!doc.documentElement.getAttribute('lang')) doc.documentElement.setAttribute('lang', 'es');

    // Enlace para saltar al contenido.
    if (!doc.querySelector('.a11y-skip')) {
      var main = doc.querySelector('main') || doc.querySelector('x-dc > div, x-dc > section') || doc.body.firstElementChild;
      if (main && !main.id) main.id = 'contenido';
      var skip = doc.createElement('a');
      skip.className = 'a11y-skip'; skip.href = '#' + (main ? main.id : 'contenido'); skip.textContent = 'Ir al contenido';
      doc.body.insertBefore(skip, doc.body.firstChild);
    }

    // Botones y enlaces de solo ícono: nombre accesible a partir del ícono.
    doc.querySelectorAll('button, a[href], span[onclick], span[style*="cursor"]').forEach(function (el) {
      if (hasText(el) || el.getAttribute('aria-label') || el.getAttribute('title')) return;
      var icon = el.querySelector('[data-lucide], svg.lucide');
      var name = icon && (icon.getAttribute('data-lucide') || (icon.getAttribute('class') || '').replace(/.*lucide-([a-z0-9-]+).*/, '$1'));
      if (name && ICON_LABELS[name]) {
        el.setAttribute('aria-label', ICON_LABELS[name]);
        if (el.tagName === 'SPAN') { el.setAttribute('role', 'button'); el.setAttribute('tabindex', '0'); }
      }
    });

    // Íconos decorativos fuera del árbol accesible.
    doc.querySelectorAll('svg.lucide, i[data-lucide]').forEach(function (i) { i.setAttribute('aria-hidden', 'true'); });

    // Campos sin <label for>: usan el texto del label anterior o el placeholder.
    doc.querySelectorAll('input:not([aria-label]):not([id])').forEach(function (input) {
      var wrap = input.parentElement, label = wrap && wrap.previousElementSibling;
      var text = label && label.tagName === 'LABEL' ? label.textContent.trim() : (input.getAttribute('placeholder') || '');
      if (input.getAttribute('data-otp') !== null) text = 'Dígito ' + (Number(input.getAttribute('data-otp')) + 1) + ' de 6';
      if (text) input.setAttribute('aria-label', text);
    });

    // Mensajes de error se anuncian; imágenes sin alt son decorativas.
    doc.querySelectorAll('[style*="rgb(239, 68, 68)"]').forEach(function (el) {
      if (el.tagName === 'DIV' && !el.getAttribute('role') && hasText(el) && !el.querySelector('button, input')) el.setAttribute('role', 'alert');
    });
    doc.querySelectorAll('img:not([alt])').forEach(function (img) { img.setAttribute('alt', ''); });

    // Navegación: el ítem activo (subrayado o resaltado) se marca para lectores de pantalla.
    doc.querySelectorAll('nav a').forEach(function (a) {
      var s = a.getAttribute('style') || '';
      if (/border-bottom(-color)?:\s*(2px solid )?(rgb\(155, 119, 230\)|#9B77E6)/.test(s) || /rgb\(237, 233, 254\)/.test(s)) a.setAttribute('aria-current', 'page');
    });
  }

  var scheduled = false;
  function schedule() { if (scheduled) return; scheduled = true; requestAnimationFrame(function () { scheduled = false; apply(); }); }
  document.addEventListener('DOMContentLoaded', function () {
    apply();
    new MutationObserver(schedule).observe(document.body, { childList: true, subtree: true });
  });
})();
