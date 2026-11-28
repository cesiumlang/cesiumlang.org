// The edition selector (cesiumlang.org#43): the latest release at the root of
// cesiumlang.org, each release also under /vX.Y.Z/, the development version
// on cesiumlang.dev. A choice opens the same page in that edition where it
// has one, else the edition's front page. editions.json and site-index.json
// come from tools/zine.
(function () {
  "use strict";

  var RELEASES_SITE = "https://cesiumlang.org/";
  var DEVELOPMENT_SITE = "https://cesiumlang.dev/";
  var select = document.getElementById("edition");
  var editionsLink = document.getElementById("editions");
  var indexLink = document.getElementById("site-index");
  if (!select || !editionsLink || !indexLink) return;

  var base = indexLink.href.slice(0, indexLink.href.lastIndexOf("/") + 1);
  var current = location.pathname.replace(/^\/+|\/+$/g, "");
  var rootPath = new URL(base).pathname.replace(/^\/+|\/+$/g, "");
  if (rootPath && current.indexOf(rootPath) === 0) current = current.slice(rootPath.length).replace(/^\/+/, "");

  var edition = /^v(\d+\.\d+\.\d+)(?:\/|$)/;
  var match = current.match(edition);
  // the page's path within its edition: spec/lexical
  var rest = match ? current.slice(match[0].length) : current;

  function json(response) { return response.json(); }

  Promise.all([fetch(editionsLink.href).then(json), fetch(indexLink.href).then(json)]).then(function (data) {
    var info = data[0];
    var releases = info.releases || [];
    var latest = releases[0];
    if (!latest && !info.development) return;
    var slugs = {};
    data[1].forEach(function (page) { slugs[page.slug] = true; });

    releases.forEach(function (release) {
      var option = document.createElement("option");
      option.value = release;
      option.textContent = "v" + release + (release === latest ? " (latest)" : "");
      select.appendChild(option);
    });
    var dev = document.createElement("option");
    dev.value = "development";
    dev.textContent = "development";
    select.appendChild(dev);

    select.value = info.development ? "development" : (match ? match[1] : latest);
    select.hidden = false;

    // where a release's page is: the latest at the root, the others under vX.Y.Z/
    function prefix(release) { return release === latest ? "" : "v" + release + "/"; }

    select.addEventListener("change", function () {
      var choice = select.value;
      var target;
      if (choice === "development") {
        target = (info.development ? base : DEVELOPMENT_SITE) + (rest ? rest + "/" : "");
      } else if (info.development) {
        // from the development site: the page of the release, by its path; an
        // older edition holds only the specification, the proposals and the
        // diagnostics
        var kept = choice === latest || /^(spec|proposals|compiler\/diagnostics)(\/|$)/.test(rest);
        target = RELEASES_SITE + prefix(choice) + (kept && rest ? rest + "/" : "");
      } else {
        var slug = prefix(choice) + rest;
        slug = slug.replace(/\/+$/, "");
        target = base + (slugs[slug] ? (slug ? slug + "/" : "") : prefix(choice));
      }
      location.href = target + location.hash;
    });
  });
})();
