import { QuartzEmitterPlugin } from "./quartz/plugins/types"
import { QuartzComponentProps } from "./quartz/components/types"
import HeaderConstructor from "./quartz/components/Header"
import BodyConstructor from "./quartz/components/Body"
import { pageResources, renderPage } from "./quartz/components/renderPage"
import { ProcessedContent, QuartzPluginData, defaultProcessedContent } from "./quartz/plugins/vfile"
import { FullPageLayout } from "./quartz/cfg"
import path from "path"
import {
  FullSlug,
  SimpleSlug,
  stripSlashes,
  joinSegments,
  pathToRoot,
  simplifySlug,
  isFolderPath,
} from "./quartz/util/path"
import { defaultListPageLayout, sharedPageComponents } from "./quartz.layout"
import { write } from "./quartz/plugins/emitters/helpers"
import { i18n, TRANSLATIONS } from "./quartz/i18n"
import { BuildCtx } from "./quartz/util/ctx"
import { StaticResources } from "./quartz/util/resources"
import { QuartzComponent, QuartzComponentConstructor } from "./quartz/components/types"
import { Date, getDate } from "./quartz/components/Date"
import { FullSlug as PathFullSlug, resolveRelative } from "./quartz/util/path"
import style from "./quartz/components/styles/listPage.scss"
import { htmlToJsx } from "./quartz/util/jsx"
import { ComponentChildren } from "preact"
import { concatenateResources } from "./quartz/util/resources"
import { trieFromAllFiles } from "./quartz/util/ctx"
import { GlobalConfiguration } from "./quartz/cfg"

// Custom sort function that respects sortorder frontmatter
export function bySortOrderAndAlphabetical(cfg: GlobalConfiguration) {
  return (f1: QuartzPluginData, f2: QuartzPluginData) => {
    // Get sortorder from frontmatter
    const f1SortOrder = f1.frontmatter?.sortorder
    const f2SortOrder = f2.frontmatter?.sortorder

    // Handle folder vs file sorting first
    const f1IsFolder = isFolderPath(f1.slug ?? "")
    const f2IsFolder = isFolderPath(f2.slug ?? "")
    
    if (f1IsFolder && !f2IsFolder) return -1
    if (!f1IsFolder && f2IsFolder) return 1

    // Both are folders or both are files
    if (typeof f1SortOrder === 'number' && typeof f2SortOrder === 'number') {
      // Both have sortorder
      return f1SortOrder - f2SortOrder
    } else if (typeof f1SortOrder === 'number' && typeof f2SortOrder !== 'number') {
      // Only f1 has sortorder, f1 comes first
      return -1
    } else if (typeof f1SortOrder !== 'number' && typeof f2SortOrder === 'number') {
      // Only f2 has sortorder, f2 comes first
      return 1
    } else {
      // Neither has sortorder, fall back to default sorting
      if (f1.dates && f2.dates) {
        // sort descending by date
        return getDate(cfg, f2)!.getTime() - getDate(cfg, f1)!.getTime()
      } else if (f1.dates && !f2.dates) {
        // prioritize files with dates
        return -1
      } else if (!f1.dates && f2.dates) {
        return 1
      }

      // otherwise, sort lexographically by title
      const f1Title = f1.frontmatter?.title?.toLowerCase() ?? ""
      const f2Title = f2.frontmatter?.title?.toLowerCase() ?? ""
      return f1Title.localeCompare(f2Title)
    }
  }
}

interface CustomFolderContentOptions {
  /**
   * Whether to display number of folders
   */
  showFolderCount: boolean
  showSubfolders: boolean
  sort?: (f1: QuartzPluginData, f2: QuartzPluginData) => number
}

const defaultOptions: CustomFolderContentOptions = {
  showFolderCount: true,
  showSubfolders: true,
}

export const CustomFolderContent = ((opts?: Partial<CustomFolderContentOptions>) => {
  const options: CustomFolderContentOptions = { ...defaultOptions, ...opts }

  const CustomPageList: QuartzComponent = (props: QuartzComponentProps) => {
    const { cfg, fileData, allFiles } = props
    
    // Apply custom sorting if provided, otherwise use sortorder sorting
    const sortFn = options.sort ?? bySortOrderAndAlphabetical(cfg)
    const sorted = allFiles.sort(sortFn)

    return (
      <ul class="section-ul">
        {sorted.map((page) => {
          const title = page.frontmatter?.title ?? i18n(cfg.locale).propertyDefaults.title
          const tags = page.frontmatter?.tags ?? []

          return (
            <li class="section-li">
              <div class="section">
                {page.dates && (
                  <p class="meta">
                    <Date date={getDate(cfg, page)!} locale={cfg.locale} />
                  </p>
                )}
                <div class="desc">
                  <h3>
                    <a href={resolveRelative(fileData.slug!, page.slug!)} class="internal">
                      {title}
                    </a>
                  </h3>
                  {page.frontmatter?.description && (
                    <p>{page.frontmatter.description}</p>
                  )}
                  {tags.length > 0 && (
                    <ul class="tags">
                      {tags.map((tag) => (
                        <li>
                          <a
                            class="internal tag-link"
                            href={resolveRelative(fileData.slug!, `tags/${tag}` as FullSlug)}
                          >
                            #{tag}
                          </a>
                        </li>
                      ))}
                    </ul>
                  )}
                </div>
              </div>
            </li>
          )
        })}
      </ul>
    )
  }

  const FolderContent: QuartzComponent = (props: QuartzComponentProps) => {
    const { tree, fileData, allFiles, cfg } = props

    const trie = (props.ctx.trie ??= trieFromAllFiles(allFiles))
    const folder = trie.findNode(fileData.slug!.split("/"))
    if (!folder) {
      return null
    }

    const allPagesInFolder: QuartzPluginData[] =
      folder.children
        .map((node) => {
          // regular file, proceed
          if (node.data) {
            return node.data
          }

          if (node.isFolder && options.showSubfolders) {
            // folders that dont have data need synthetic files
            const getMostRecentDates = (): QuartzPluginData["dates"] => {
              let maybeDates: QuartzPluginData["dates"] | undefined = undefined
              for (const child of node.children) {
                if (child.data?.dates) {
                  // compare all dates and assign to maybeDates if its more recent or its not set
                  if (!maybeDates) {
                    maybeDates = { ...child.data.dates }
                  } else {
                    if (child.data.dates.created > maybeDates.created) {
                      maybeDates.created = child.data.dates.created
                    }

                    if (child.data.dates.modified > maybeDates.modified) {
                      maybeDates.modified = child.data.dates.modified
                    }

                    if (child.data.dates.published > maybeDates.published) {
                      maybeDates.published = child.data.dates.published
                    }
                  }
                }
              }
              return (
                maybeDates ?? {
                  created: new Date(),
                  modified: new Date(),
                  published: new Date(),
                }
              )
            }

            return {
              slug: node.slug,
              dates: getMostRecentDates(),
              frontmatter: {
                title: node.displayName,
                tags: [],
              },
            }
          }
        })
        .filter((page) => page !== undefined) ?? []
    const cssClasses: string[] = fileData.frontmatter?.cssclasses ?? []
    const classes = cssClasses.join(" ")
    const listProps = {
      ...props,
      allFiles: allPagesInFolder,
    }

    const content = (
      (tree as any).children.length === 0
        ? fileData.description
        : htmlToJsx(fileData.filePath!, tree)
    ) as ComponentChildren

    return (
      <div class="popover-hint">
        <article class={classes}>{content}</article>
        <div class="page-listing">
          {options.showFolderCount && (
            <p>
              {i18n(cfg.locale).pages.folderContent.itemsUnderFolder({
                count: allPagesInFolder.length,
              })}
            </p>
          )}
          <div>
            <CustomPageList {...listProps} />
          </div>
        </div>
      </div>
    )
  }

  FolderContent.css = style
  return FolderContent
}) satisfies QuartzComponentConstructor

interface FolderPageOptions extends FullPageLayout {
  sort?: (f1: QuartzPluginData, f2: QuartzPluginData) => number
}

async function* processFolderInfo(
  ctx: BuildCtx,
  folderInfo: Record<SimpleSlug, ProcessedContent>,
  allFiles: QuartzPluginData[],
  opts: FullPageLayout,
  resources: StaticResources,
) {
  for (const [folder, folderContent] of Object.entries(folderInfo) as [
    SimpleSlug,
    ProcessedContent,
  ][]) {
    const slug = joinSegments(folder, "index") as FullSlug
    const [tree, file] = folderContent
    const cfg = ctx.cfg.configuration
    const externalResources = pageResources(pathToRoot(slug), resources)
    const componentData: QuartzComponentProps = {
      ctx,
      fileData: file.data,
      externalResources,
      cfg,
      children: [],
      tree,
      allFiles,
    }

    const content = renderPage(cfg, slug, componentData, opts, externalResources)
    yield write({
      ctx,
      content,
      slug,
      ext: ".html",
    })
  }
}

function computeFolderInfo(
  folders: Set<SimpleSlug>,
  content: ProcessedContent[],
  locale: keyof typeof TRANSLATIONS,
): Record<SimpleSlug, ProcessedContent> {
  // Create default folder descriptions
  const folderInfo: Record<SimpleSlug, ProcessedContent> = Object.fromEntries(
    [...folders].map((folder) => [
      folder,
      defaultProcessedContent({
        slug: joinSegments(folder, "index") as FullSlug,
        frontmatter: {
          title: `${i18n(locale).pages.folderContent.folder}: ${folder}`,
          tags: [],
        },
      }),
    ]),
  )

  // Update with actual content if available
  for (const [tree, file] of content) {
    const slug = stripSlashes(simplifySlug(file.data.slug!)) as SimpleSlug
    if (folders.has(slug)) {
      folderInfo[slug] = [tree, file]
    }
  }

  return folderInfo
}

function _getFolders(slug: FullSlug): SimpleSlug[] {
  var folderName = path.dirname(slug ?? "") as SimpleSlug
  const parentFolderNames = [folderName]

  while (folderName !== ".") {
    folderName = path.dirname(folderName ?? "") as SimpleSlug
    parentFolderNames.push(folderName)
  }
  return parentFolderNames
}

export const CustomFolderPage: QuartzEmitterPlugin<Partial<FolderPageOptions>> = (userOpts) => {
  const opts: FullPageLayout = {
    ...sharedPageComponents,
    ...defaultListPageLayout,
    pageBody: CustomFolderContent({ sort: userOpts?.sort }),
    ...userOpts,
  }

  const { head: Head, header, beforeBody, pageBody, afterBody, left, right, footer: Footer } = opts
  const Header = HeaderConstructor()
  const Body = BodyConstructor()

  return {
    name: "CustomFolderPage",
    getQuartzComponents() {
      return [
        Head,
        Header,
        Body,
        ...header,
        ...beforeBody,
        pageBody,
        ...afterBody,
        ...left,
        ...right,
        Footer,
      ]
    },
    async *emit(ctx, content, resources) {
      const allFiles = content.map((c) => c[1].data)
      const cfg = ctx.cfg.configuration

      const folders: Set<SimpleSlug> = new Set(
        allFiles.flatMap((data) => {
          return data.slug
            ? _getFolders(data.slug).filter(
                (folderName) => folderName !== "." && folderName !== "tags",
              )
            : []
        }),
      )

      const folderInfo = computeFolderInfo(folders, content, cfg.locale)
      yield* processFolderInfo(ctx, folderInfo, allFiles, opts, resources)
    },
    async *partialEmit(ctx, content, resources, changeEvents) {
      const allFiles = content.map((c) => c[1].data)
      const cfg = ctx.cfg.configuration

      // Find all folders that need to be updated based on changed files
      const affectedFolders: Set<SimpleSlug> = new Set()
      for (const changeEvent of changeEvents) {
        if (!changeEvent.file) continue
        const slug = changeEvent.file.data.slug!
        const folders = _getFolders(slug).filter(
          (folderName) => folderName !== "." && folderName !== "tags",
        )
        folders.forEach((folder) => affectedFolders.add(folder))
      }

      // If there are affected folders, rebuild their pages
      if (affectedFolders.size > 0) {
        const folderInfo = computeFolderInfo(affectedFolders, content, cfg.locale)
        yield* processFolderInfo(ctx, folderInfo, allFiles, opts, resources)
      }
    },
  }
}