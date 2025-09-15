import { QuartzConfig } from "./quartz/cfg"
import * as Plugin from "./quartz/plugins"
import { CustomSyntaxHighlighting } from "./custom-syntax-highlighting"
import { FrontmatterIndex } from "./frontmatter-index"
import { CustomFolderPage } from "./custom-folder-page"
import * as fs from "fs"
import * as path from "path"
import { getHighlighter } from "shiki";

// Path to the Cesium TextMate grammar file at workspace root.
// Don't forget this file gets copied to quartz_repo during
// the build action, so the path needs an extra ../ here.
const cesiumGrammarPath = path.resolve("../grammar/cesium.tmGrammar.json")
const cesiumGrammar = JSON.parse(fs.readFileSync(cesiumGrammarPath, "utf-8"))

// // Load custom Cesium theme based on your VS Code settings
// const cesiumThemePath = path.resolve("./cesium-shiki-theme.json")
// const cesiumTheme = JSON.parse(fs.readFileSync(cesiumThemePath, "utf-8"))

/**
 * Quartz 4 Configuration
 *
 * See https://quartz.jzhao.xyz/configuration for more information.
 */
const config: QuartzConfig = {
  configuration: {
    pageTitle: "Cesium",
    pageTitleSuffix: " | Cesium Programming Language",
    enableSPA: true,
    enablePopovers: true,
    analytics: null,
    // {
    //   provider: "plausible",
    // },
    locale: "en-US",
    baseUrl: "cesiumlang.dev",
    ignorePatterns: ["private", "templates", ".obsidian"],
    defaultDateType: "modified",
    theme: {
      fontOrigin: "googleFonts",
      cdnCaching: true,
      typography: {
        // title: "Schibsted Grotesk",
        header: "Schibsted Grotesk",
        body: "Source Sans Pro",
        code: "IBM Plex Mono",
      },
      colors: {
        lightMode: {
          light: "#faf8f8",
          lightgray: "#e5e5e5",
          gray: "#b8b8b8",
          darkgray: "#4e4e4e",
          dark: "#2b2b2b",
          secondary: "#284b63",
          tertiary: "#84a59d",
          highlight: "rgba(143, 159, 169, 0.15)",
          textHighlight: "#fff23688",
        },
        darkMode: {
          light: "#161618",
          lightgray: "#393639",
          gray: "#646464",
          darkgray: "#d4d4d4",
          dark: "#ebebec",
          secondary: "#7b97aa",
          tertiary: "#84a59d",
          highlight: "rgba(143, 159, 169, 0.15)",
          textHighlight: "#b3aa0288",
        },
      },
    },
  },
  plugins: {
    transformers: [
      Plugin.FrontMatter(),
      Plugin.CreatedModifiedDate({
        priority: ["frontmatter", "git", "filesystem"],
      }),
      // Plugin.SyntaxHighlighting(),
      CustomSyntaxHighlighting({
        theme: {
          light: "light-plus",
          dark: "dark-plus",
          // dark: cesiumTheme,
        },
        keepBackground: true,
        defaultLang: "cesium",
        getHighlighter: (options) =>
          getHighlighter({
            ...options,
            langs: [
              "plaintext",
              async () => cesiumGrammar,
            ],
          }),
      }),
      Plugin.ObsidianFlavoredMarkdown({ enableInHtmlEmbed: false }),
      Plugin.GitHubFlavoredMarkdown(),
      Plugin.TableOfContents({ maxDepth: 6 }),
      Plugin.CrawlLinks({ markdownLinkResolution: "shortest" }),
      Plugin.Description(),
      Plugin.Latex({ renderEngine: "katex" }),
    ],
    filters: [Plugin.RemoveDrafts()],
    emitters: [
      Plugin.AliasRedirects(),
      Plugin.ComponentResources(),
      Plugin.ContentPage(),
      CustomFolderPage(),
      Plugin.TagPage(),
      Plugin.ContentIndex({
        enableSiteMap: true,
        enableRSS: true,
      }),
      Plugin.Assets(),
      Plugin.Static(),
      Plugin.Favicon(),
      Plugin.NotFoundPage(),
      // Comment out CustomOgImages to speed up build time
      Plugin.CustomOgImages(),
      FrontmatterIndex(),
    ],
  },
}

export default config
