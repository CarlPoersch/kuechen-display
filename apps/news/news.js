// ============================================================
// Unterapp "News": Top-Meldungen in drei Rubriken.
// Deutschland und Welt von der Tagesschau, KI von heise.
// Eilmeldungen stehen oben und sind rot hervorgehoben.
//
// Antippen öffnet den Artikel direkt in Hubert (#news/a/<link>).
// Warum nicht im Browser: Im geführten Zugriff lässt sich Safari nicht öffnen,
// und so bleibt man in Hubert.
// ============================================================
(function () {
  var F = Hubert.Feeds, esc = Launcher.esc;
  var TABS = [["de", "Deutschland", "tagesschau"], ["welt", "Welt", "tagesschau"], ["ki", "KI", "heise online"]];
  var articles = {}; // Zwischenspeicher für gelesene Artikel (nur solange die App offen ist)

  function teaser(n) {
    return '<div class="nw-item" data-home-go="' + esc(F.articleRoute(n)) + '">' +
      (n.top ? '<div class="nw-top">' + esc(n.top) + "</div>" : "") +
      '<div class="nw-t">' + esc(n.t) + "</div>" +
      (n.s ? '<div class="nw-s">' + esc(n.s) + "</div>" : "") +
      '<div class="nw-d">' + esc(F.ago(n.d)) + "</div></div>";
  }

  // ---------- Liste ----------
  function mountList(el, ctx) {
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
        return '<div class="h-break" data-home-go="' + esc(F.articleRoute(b)) + '"><b>EILMELDUNG</b> ' + esc(b.t) + "</div>";
      }).join("");
      var list = c.data[tab] || [];
      listEl.innerHTML = list.length ? list.map(teaser).join("") : '<div class="empty">Gerade keine Meldungen.</div>';
      var src = TABS.filter(function (t) { return t[0] === tab; })[0][2];
      foot.textContent = "Stand " + F.hhmm(c.at) + " · Quelle: " + src;
    }

    draw();
    ctx.onCleanup(F.subscribe("news", draw));
    ctx.onCleanup(F.keepFresh("news"));
    var t = setInterval(draw, 60000);
    ctx.onCleanup(function () { clearInterval(t); });
  }

  // ---------- Artikel ----------
  function findTeaser(key) {
    var c = F.cached("news"), d = c && c.data, hit = null;
    if (d) ["breaking", "de", "welt", "ki"].forEach(function (k) {
      (d[k] || []).forEach(function (n) { if (!hit && (n.x === key || n.u === key)) hit = n; });
    });
    return hit;
  }

  function mountArticle(el, ctx, key) {
    ctx.setTitle("Artikel");
    ctx.setBack("Zurück", null);
    var t = findTeaser(key);
    // Sofort Überschrift aus der Liste zeigen, Text lädt nach
    function render(a, state) {
      var h = '<article class="ar">';
      var top = (a && a.top) || (t && t.top), title = (a && a.t) || (t && t.t) || "", date = (a && a.d) || (t && t.d);
      if (top) h += '<div class="ar-top">' + esc(top) + "</div>";
      h += '<h1 class="ar-t">' + esc(title) + "</h1>";
      h += '<div class="ar-meta">' + (date ? esc(F.ago(date)) + " · " : "") + esc((a && a.src) || "") + "</div>";
      if (a && a.img) h += '<img class="ar-img" src="' + esc(a.img) + '" alt="">';
      if (state === "loading") h += '<p class="ar-p ar-muted">' + esc((t && t.s) || "") + "</p><p class=\"ar-muted\">Artikel lädt …</p>";
      else if (state === "error" || !a.blocks || !a.blocks.length) {
        h += (t && t.s ? '<p class="ar-p">' + esc(t.s) + "</p>" : "") +
          '<p class="ar-muted">Den vollständigen Text konnte Hubert nicht laden' +
          (a && a.plus ? " (heise+-Artikel, nur für Abonnenten)" : "") + ".</p>";
      } else {
        h += a.blocks.map(function (b) {
          return b.k === "h" ? '<h2 class="ar-h">' + esc(b.t) + "</h2>"
            : b.k === "q" ? '<blockquote class="ar-q">' + esc(b.t) + "</blockquote>"
            : '<p class="ar-p">' + esc(b.t) + "</p>";
        }).join("");
      }
      h += '<div class="sp-foot">Quelle: ' + esc((a && a.src) || "") + "</div></article>";
      el.innerHTML = h;
    }
    if (articles[key]) { render(articles[key], "ok"); return; }
    render(null, "loading");
    var alive = true;
    ctx.onCleanup(function () { alive = false; });
    F.api("article?u=" + encodeURIComponent(key)).then(function (a) {
      articles[key] = a;
      if (alive) render(a, "ok");
    }, function () { if (alive) render({}, "error"); });
  }

  Launcher.register({
    id: "news",
    name: "News",
    icon: "📰",
    color: "#3A4A6B",
    mount: function (el, ctx) {
      if (ctx.sub.indexOf("a/") === 0) mountArticle(el, ctx, ctx.sub.slice(2));
      else mountList(el, ctx);
    }
  });
})();
