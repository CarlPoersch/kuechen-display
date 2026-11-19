// ============================================================
// Unterapp "News": Top-Meldungen in drei Rubriken.
// Deutschland und Welt von der Tagesschau, KI von heise.
// Eilmeldungen stehen oben und sind rot hervorgehoben.
// Antippen öffnet den Artikel (in der App-Hülle: in Safari).
// ============================================================
(function () {
  var F = Hubert.Feeds, esc = Launcher.esc;
  var TABS = [["de", "Deutschland", "tagesschau"], ["welt", "Welt", "tagesschau"], ["ki", "KI", "heise online"]];

  Launcher.register({
    id: "news",
    name: "News",
    icon: "📰",
    color: "#3A4A6B",
    mount: function (el, ctx) {
      var tab = ctx.storage.get("tab", "de");
      el.innerHTML = '<div class="nw-wrap"><div class="nw-break"></div><div class="sp-tabs">' +
        TABS.map(function (t) { return '<button data-t="' + t[0] + '">' + t[1] + "</button>"; }).join("") +
        '</div><div class="nw-list"></div><div class="sp-foot"></div></div>';
      var listEl = el.querySelector(".nw-list"), foot = el.querySelector(".sp-foot"), brEl = el.querySelector(".nw-break");
      var btns = el.querySelectorAll(".sp-tabs button");
      btns.forEach(function (b) {
        b.onclick = function () { tab = b.getAttribute("data-t"); ctx.storage.set("tab", tab); draw(); el.parentNode.scrollTop = 0; };
      });

      function draw() {
        btns.forEach(function (b) { b.classList.toggle("on", b.getAttribute("data-t") === tab); });
        var c = F.cached("news");
        if (!F.cloud()) { listEl.innerHTML = '<div class="empty">News gibt es nur in der Cloud-Version.</div>'; return; }
        if (!c) { listEl.innerHTML = '<div class="empty">Lädt …</div>'; return; }
        brEl.innerHTML = (c.data.breaking || []).map(function (b) {
          return '<a class="h-break" href="' + esc(b.u) + '" target="_blank" rel="noopener"><b>EILMELDUNG</b> ' + esc(b.t) + "</a>";
        }).join("");
        var list = c.data[tab] || [];
        listEl.innerHTML = list.length ? list.map(function (n) {
          return '<a class="nw-item" href="' + esc(n.u) + '" target="_blank" rel="noopener">' +
            (n.top ? '<div class="nw-top">' + esc(n.top) + "</div>" : "") +
            '<div class="nw-t">' + esc(n.t) + "</div>" +
            (n.s ? '<div class="nw-s">' + esc(n.s) + "</div>" : "") +
            '<div class="nw-d">' + esc(F.ago(n.d)) + "</div></a>";
        }).join("") : '<div class="empty">Gerade keine Meldungen.</div>';
        var src = TABS.filter(function (t) { return t[0] === tab; })[0][2];
        foot.textContent = "Stand " + F.hhmm(c.at) + " · Quelle: " + src;
      }

      draw();
      ctx.onCleanup(F.subscribe("news", draw));
      ctx.onCleanup(F.keepFresh("news"));
      var t = setInterval(draw, 60000);
      ctx.onCleanup(function () { clearInterval(t); });
    }
  });
})();
