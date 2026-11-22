# cesiumlang.org

This repo defines the files used to generate the official [Cesium website](https://cesiumlang.org).

The site is built with [Zine](https://zine-ssg.io), a static site generator written in Zig, from plain Markdown pages. The pages do not depend on the generator: a Zig program, `tools/zine`, turns them into what Zine reads, so another generator (or the one that is to be written in Cesium, [cesiumlang/cesiumlang.org#23](https://github.com/cesiumlang/cesiumlang.org/issues/23)) can take their place. The rebuild is tracked in [cesiumlang/cesiumlang.org#28](https://github.com/cesiumlang/cesiumlang.org/issues/28).

## Repository layout

Clone it with `--recurse-submodules`. To work on all Cesium repositories together, clone [cesium-workspace](https://github.com/cesiumlang/cesium-workspace) instead, which has this repository, the compiler and the others as submodules side by side.

| Path | What |
| --- | --- |
| `content/` | The pages of the site as Markdown: language reference, compiler documentation, draft specification, news. Links between pages are relative Markdown links to `.md` files (`[the specification](../spec/index.md)`); callouts are `> [!warning] Title` |
| `site/` | What Zine needs besides the pages: `zine.ziggy`, the layouts, and the style sheets and scripts in `assets/` |
| `tools/zine/` | `cesium-site-gen`: writes the input of Zine from `content/` into `site/content/` and `site/assets/`, with the code blocks highlighted and `site-index.json` for the explorer and the search |
| `tools/ai/` | `cesium-site-ai`: writes `llms.txt`, a Markdown version of every page and the Cesium skill for AI models ([cesiumlang/cesiumlang.org#25](https://github.com/cesiumlang/cesiumlang.org/issues/25)); also the units the other tool shares (pages, links, rules) |
| `build.zig` | Builds the tools and the site |
| `grammar/` | Submodule: [cesiumlang/grammar](https://github.com/cesiumlang/grammar), the Tree-sitter grammar and highlighter that color Cesium code on the site |
| `.cspell/cesium/` | Submodule: [cesiumlang/cspell-cesium](https://github.com/cesiumlang/cspell-cesium), the spelling dictionary of Cesium terms |

`cesiumlang.org.code-workspace` is the VS Code workspace for the site. It repeats the settings of the submodules' own workspace files, so opening this one workspace is enough.

## Setup

The site needs Zig 0.17.1. CI installs that version, set by hand as `ZIG_VERSION` in `.github/workflows/deploy.yml` (and in the workflow of cesiumlang/cesiumlang.dev). Locally, use the Zig of the Cesium devkit, which is that version, from the compiler's repository:

```bash
bash ../cesium-src/tools/fetch-devkit.sh   # in cesium-workspace; or clone cesiumlang/cesium anywhere
```

With [direnv](https://direnv.net), `.envrc` puts `../cesium-src/.devkit/zig` on the `PATH` when you enter the directory. Run `direnv allow` once. Without it, call that `zig` yourself.

The first build compiles Zine and takes some minutes; later builds are quick.

## Building

```bash
zig build            # the site, in zig-out/public
zig build serve      # the dev server, at http://localhost:1990
zig build gen        # only the input of Zine: site/content and site/assets
zig build test       # the tests of the tools
```

After `zig build`, add the files for AI models to the output:

```bash
zig-out/bin/cesium-site-ai --out zig-out/public --host cesiumlang.org
```

`site/content/`, `site/assets/site-index.json` and `site/assets/img/` are written by `cesium-site-gen` and are not committed; edit `content/` instead.

The site is to include documentation generated from the compiler's source ([cesiumlang/cesium#64](https://github.com/cesiumlang/cesium/issues/64)); nothing reads the source yet. Each documented symbol is to be a page of its own, which the explorer, search and backlinks pick up from `site-index.json` like any other page.

## Writing pages

A page is a Markdown file in `content/` with a short front matter:

```markdown
---
title: "Error Handling"
tags: ["errors", "catch"]
sortorder: 11
---
```

`sortorder` orders the pages of a directory in the explorer. A directory is a section when it has an `index.md`. Code blocks without a language, and those marked `cesium`, are highlighted as Cesium.

## The development site

Every push to `dev` and to a branch named `web/...` is built at <https://cesiumlang.dev>, by the repository [cesiumlang/cesiumlang.dev](https://github.com/cesiumlang/cesiumlang.dev) (a repository has one Pages domain), through the workflow `dev-site.yml`. cesiumlang.org is built from `main` by `deploy.yml`.
