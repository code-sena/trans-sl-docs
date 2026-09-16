(function () {
  function apply() {
    var p = {};
    try { p = JSON.parse(localStorage.getItem("ts-prefs") || "{}") || {}; } catch (e) {}
    var el = document.documentElement;
    el.setAttribute("data-theme", p.dark ? "dark" : "light");
    el.setAttribute("data-accent", p.accent === "green" ? "green" : "purple");
  }
  apply();
  window.__tsApplyTheme = apply;
  window.addEventListener("storage", function (e) { if (e.key === "ts-prefs") apply(); });
})();
