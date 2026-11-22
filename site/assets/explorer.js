// The explorer, breadcrumbs, tags, search and the toggles. Everything comes
// from site-index.json (written by tools/zine), so no generator is assumed.
(function () {
  "use strict";

  var indexLink = document.getElementById("site-index");
  var base = indexLink.href.slice(0, indexLink.href.lastIndexOf("/") + 1);
  var current = location.pathname.replace(/^\/+|\/+$/g, "");
  var rootPath = new URL(base).pathname.replace(/^\/+|\/+$/g, "");
  if (rootPath && current.indexOf(rootPath) === 0) current = current.slice(rootPath.length).replace(/^\/+/, "");

  function store(key, value) {
    try { localStorage.setItem(key, value); } catch (e) {}
  }
  function stored(key) {
    try { return localStorage.getItem(key); } catch (e) { return null; }
  }

  function el(tag, attrs, text) {
    var node = document.createElement(tag);
    for (var name in attrs || {}) node.setAttribute(name, attrs[name]);
    if (text) node.textContent = text;
    return node;
  }

  function tagSlug(tag) {
    return tag.toLowerCase().replace(/[^a-z0-9]/g, "-");
  }

  function url(slug) {
    return base + (slug ? slug + "/" : "");
  }

  // ---- the tree ------------------------------------------------------

  function byOrder(a, b) {
    return (a.order - b.order) || a.title.localeCompare(b.title);
  }

  function makeTree(pages) {
    var root = { name: "", entry: null, folders: {}, pages: [] };
    pages.forEach(function (page) {
      if (page.slug === "" || /^tags(\/|$)/.test(page.slug)) return;
      var parts = page.slug.split("/");
      var node = root;
      var folderDepth = page.index ? parts.length : parts.length - 1;
      for (var i = 0; i < folderDepth; i++) {
        var name = parts[i];
        node.folders[name] = node.folders[name] || { name: name, entry: null, folders: {}, pages: [] };
        node = node.folders[name];
      }
      if (page.index) node.entry = page;
      else node.pages.push(page);
    });
    return root;
  }

  function folderOrder(node) {
    return node.entry ? node.entry.order : Number.MAX_SAFE_INTEGER;
  }

  function folderTitle(node) {
    return node.entry ? node.entry.title : node.name;
  }

  function renderNode(node, depth) {
    var list = el("ul");
    var items = [];
    Object.keys(node.folders).forEach(function (name) {
      var folder = node.folders[name];
      items.push({ order: folderOrder(folder), title: folderTitle(folder), folder: folder });
    });
    node.pages.forEach(function (page) {
      items.push({ order: page.order, title: page.title, page: page });
    });
    items.sort(byOrder);
    items.forEach(function (item) {
      var li = el("li");
      if (item.folder) {
        var folder = item.folder;
        var slug = folder.entry ? folder.entry.slug : null;
        var open = stored("explorer:" + (slug || folder.name));
        var contains = slug !== null && (current === slug || current.indexOf(slug + "/") === 0);
        li.className = "folder" + (contains || open === "open" ? " open" : "");
        var row = el("div", { class: "row" });
        var fold = el("button", { class: "fold", type: "button", "aria-label": "Expand or collapse" }, "▸");
        fold.addEventListener("click", function () {
          li.classList.toggle("open");
          store("explorer:" + (slug || folder.name), li.classList.contains("open") ? "open" : "closed");
        });
        row.appendChild(fold);
        row.appendChild(link(folder.entry, folderTitle(folder)));
        li.appendChild(row);
        li.appendChild(renderNode(folder, depth + 1));
      } else {
        li.appendChild(link(item.page, item.page.title));
      }
      list.appendChild(li);
    });
    return list;
  }

  function link(entry, title) {
    if (!entry) return el("span", {}, title);
    var a = el("a", { href: url(entry.slug) }, title);
    if (entry.slug === current) a.className = "current";
    return a;
  }

  // ---- search --------------------------------------------------------

  function setupSearch(pages) {
    var box = document.getElementById("search");
    var input = document.getElementById("search-input");
    var results = document.getElementById("search-results");

    function open() {
      box.hidden = false;
      input.value = "";
      results.textContent = "";
      input.focus();
    }
    function close() {
      box.hidden = true;
    }

    document.getElementById("search-button").addEventListener("click", open);
    box.addEventListener("click", function (event) {
      if (event.target === box) close();
    });
    document.addEventListener("keydown", function (event) {
      var typing = /^(INPUT|TEXTAREA)$/.test((event.target.tagName || ""));
      if (event.key === "Escape") close();
      else if (event.key === "/" && !typing) { event.preventDefault(); open(); }
    });

    input.addEventListener("input", function () {
      var terms = input.value.toLowerCase().split(/\s+/).filter(Boolean);
      results.textContent = "";
      if (!terms.length) return;
      var hits = [];
      pages.forEach(function (page) {
        var score = 0;
        var title = page.title.toLowerCase();
        var text = page.text.toLowerCase();
        var headings = page.headings.map(function (h) { return h.text.toLowerCase(); }).join(" ");
        var tags = page.tags.join(" ").toLowerCase();
        for (var i = 0; i < terms.length; i++) {
          var t = terms[i];
          var s = (title.indexOf(t) >= 0 ? 10 : 0) + (tags.indexOf(t) >= 0 ? 5 : 0) +
            (headings.indexOf(t) >= 0 ? 3 : 0) + (text.indexOf(t) >= 0 ? 1 : 0);
          if (!s) { score = 0; break; }
          score += s;
        }
        if (score) hits.push({ page: page, score: score, text: text });
      });
      hits.sort(function (a, b) { return b.score - a.score; });
      hits.slice(0, 20).forEach(function (hit) {
        var a = el("a", { href: url(hit.page.slug) });
        a.appendChild(el("strong", {}, hit.page.title));
        var at = Math.max(0, hit.text.indexOf(terms[0]) - 40);
        a.appendChild(el("small", {}, hit.page.text.slice(at, at + 140)));
        results.appendChild(a);
      });
    });
  }

  // ---- the page ------------------------------------------------------

  function setupPage(pages) {
    var entry = pages.filter(function (p) { return p.slug === current; })[0];

    var crumbs = document.getElementById("breadcrumbs");
    var parts = current ? current.split("/") : [];
    var prefix = "";
    crumbs.appendChild(el("a", { href: url("") }, "Home"));
    parts.slice(0, -1).forEach(function (part) {
      prefix = prefix ? prefix + "/" + part : part;
      var folder = pages.filter(function (p) { return p.slug === prefix && p.index; })[0];
      crumbs.appendChild(el("a", { href: url(prefix) }, folder ? folder.title : part));
    });

    var meta = document.getElementById("page-meta");
    if (meta && entry) {
      entry.tags.forEach(function (tag) {
        var a = el("a", { class: "tag", href: url("tags/" + tagSlug(tag)) }, tag);
        meta.appendChild(a);
      });
    }
  }

  function setupToggles() {
    var root = document.documentElement;
    document.getElementById("theme-toggle").addEventListener("click", function () {
      root.dataset.theme = root.dataset.theme === "dark" ? "light" : "dark";
      store("theme", root.dataset.theme);
    });
    document.getElementById("reader-toggle").addEventListener("click", function () {
      if (root.dataset.reader === "on") delete root.dataset.reader;
      else root.dataset.reader = "on";
      store("reader", root.dataset.reader || "off");
    });
  }

  setupToggles();
  fetch(indexLink.href)
    .then(function (response) { return response.json(); })
    .then(function (pages) {
      document.getElementById("explorer").appendChild(renderNode(makeTree(pages), 0));
      setupPage(pages);
      setupSearch(pages);
    });
})();
