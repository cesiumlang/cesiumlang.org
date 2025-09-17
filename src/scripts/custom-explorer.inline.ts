import { FileTrieNode } from "../quartz/util/fileTrie"
import { FullSlug, resolveRelative, simplifySlug } from "../quartz/util/path"
import { ContentDetails } from "../quartz/plugins/emitters/contentIndex"

type MaybeHTMLElement = HTMLElement | undefined

// Extended ContentDetails to include frontmatter data
interface ExtendedContentDetails extends ContentDetails {
  frontmatter?: {
    sortorder?: number
    [key: string]: any
  }
}

interface ParsedOptions {
  folderClickBehavior: "collapse" | "link"
  folderDefaultState: "collapsed" | "open"
  useSavedState: boolean
  sortFn: (a: FileTrieNode, b: FileTrieNode) => number
  filterFn: (node: FileTrieNode) => boolean
  mapFn: (node: FileTrieNode) => void
  order: "sort" | "filter" | "map"[]
}

type FolderState = {
  path: string
  collapsed: boolean
}

let currentExplorerState: Array<FolderState>
let frontmatterCache: Map<string, any> = new Map()

function toggleExplorer(this: HTMLElement) {
  const nearestExplorer = this.closest(".explorer") as HTMLElement
  if (!nearestExplorer) return
  const explorerCollapsed = nearestExplorer.classList.toggle("collapsed")
  nearestExplorer.setAttribute(
    "aria-expanded",
    nearestExplorer.getAttribute("aria-expanded") === "true" ? "false" : "true",
  )

  if (!explorerCollapsed) {
    document.documentElement.classList.add("mobile-no-scroll")
  } else {
    document.documentElement.classList.remove("mobile-no-scroll")
  }
}

function toggleFolder(evt: MouseEvent) {
  evt.stopPropagation()
  const target = evt.target as MaybeHTMLElement
  if (!target) return

  const isSvg = target.nodeName === "svg"

  const folderContainer = (
    isSvg
      ? target.parentElement
      : target.parentElement?.parentElement
  ) as MaybeHTMLElement
  if (!folderContainer) return
  const childFolderContainer = folderContainer.nextElementSibling as MaybeHTMLElement
  if (!childFolderContainer) return

  childFolderContainer.classList.toggle("open")

  const isCollapsed = !childFolderContainer.classList.contains("open")
  setFolderState(childFolderContainer, isCollapsed)

  const currentFolderState = currentExplorerState.find(
    (item) => item.path === folderContainer.dataset.folderpath,
  )
  if (currentFolderState) {
    currentFolderState.collapsed = isCollapsed
  } else {
    currentExplorerState.push({
      path: folderContainer.dataset.folderpath as FullSlug,
      collapsed: isCollapsed,
    })
  }

  const stringifiedFileTree = JSON.stringify(currentExplorerState)
  localStorage.setItem("fileTree", stringifiedFileTree)
}

function createFileNode(currentSlug: FullSlug, node: FileTrieNode): HTMLLIElement {
  const template = document.getElementById("template-file") as HTMLTemplateElement
  const clone = template.content.cloneNode(true) as DocumentFragment
  const li = clone.querySelector("li") as HTMLLIElement
  const a = li.querySelector("a") as HTMLAnchorElement
  a.href = resolveRelative(currentSlug, node.slug)
  a.dataset.for = node.slug
  a.textContent = node.displayName
  a.classList.add("file-title")

  if (currentSlug === node.slug) {
    a.classList.add("active")
  }

  // Check if we have TOC data for this file
  const slug = node.slug
  const frontmatter = frontmatterCache.get(slug)
  const toc = frontmatter?.toc

  if (toc && toc.length > 0) {
    // Create a nested list for headers
    const headersList = document.createElement("ul")
    headersList.classList.add("file-headers")
    
    // Initially collapsed
    headersList.style.display = "none"
    
    // Create toggle button for headers
    const toggleButton = document.createElement("button")
    toggleButton.classList.add("header-toggle")
    toggleButton.innerHTML = `
      <svg xmlns="http://www.w3.org/2000/svg" width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="header-fold">
        <polyline points="6 9 12 15 18 9"></polyline>
      </svg>
    `
    
    // Add click handler for toggle
    toggleButton.addEventListener("click", (e) => {
      e.preventDefault()
      e.stopPropagation()
      
      const isOpen = headersList.style.display !== "none"
      headersList.style.display = isOpen ? "none" : "block"
      toggleButton.classList.toggle("open", !isOpen)
    })
    
    // Insert toggle button before the file title (on the left like main tree)
    a.parentElement?.insertBefore(toggleButton, a)
    
    // Create header links
    toc.forEach((tocEntry: any) => {
      const headerLi = document.createElement("li")
      headerLi.classList.add("header-item", `header-depth-${tocEntry.depth}`)
      
      const headerLink = document.createElement("a")
      headerLink.href = resolveRelative(currentSlug, node.slug) + `#${tocEntry.slug}`
      headerLink.textContent = tocEntry.text
      headerLink.classList.add("header-link")
      
      headerLi.appendChild(headerLink)
      headersList.appendChild(headerLi)
    })
    
    // Add the headers list after the toggle button
    toggleButton.parentElement?.insertBefore(headersList, toggleButton.nextSibling)
  }

  return li
}

function createFolderNode(
  currentSlug: FullSlug,
  node: FileTrieNode,
  opts: ParsedOptions,
): HTMLLIElement {
  const template = document.getElementById("template-folder") as HTMLTemplateElement
  const clone = template.content.cloneNode(true) as DocumentFragment
  const li = clone.querySelector("li") as HTMLLIElement
  const folderContainer = li.querySelector(".folder-container") as HTMLElement
  const titleContainer = folderContainer.querySelector("div") as HTMLElement
  const folderOuter = li.querySelector(".folder-outer") as HTMLElement
  const ul = folderOuter.querySelector("ul") as HTMLUListElement

  const folderPath = node.slug
  folderContainer.dataset.folderpath = folderPath

  if (opts.folderClickBehavior === "link") {
    const button = titleContainer.querySelector(".folder-button") as HTMLElement
    const a = document.createElement("a")
    a.href = resolveRelative(currentSlug, folderPath)
    a.dataset.for = folderPath
    a.className = "folder-title"
    a.textContent = node.displayName
    button.replaceWith(a)
  } else {
    const span = titleContainer.querySelector(".folder-title") as HTMLElement
    span.textContent = node.displayName
  }

  const isCollapsed =
    currentExplorerState.find((item) => item.path === folderPath)?.collapsed ??
    opts.folderDefaultState === "collapsed"

  const simpleFolderPath = simplifySlug(folderPath)
  const folderIsPrefixOfCurrentSlug =
    simpleFolderPath === currentSlug.slice(0, simpleFolderPath.length)

  if (!isCollapsed || folderIsPrefixOfCurrentSlug) {
    folderOuter.classList.add("open")
  }

  for (const child of node.children) {
    const childNode = child.isFolder
      ? createFolderNode(currentSlug, child, opts)
      : createFileNode(currentSlug, child)
    ul.appendChild(childNode)
  }

  return li
}

// Enhanced sort function that checks frontmatter for sortorder
function createCustomSortFn() {
  return (a: FileTrieNode, b: FileTrieNode) => {
    const getSortOrder = (node: FileTrieNode) => {
      if (node.isFolder) return null
      
      // Check if we have cached frontmatter data
      const slug = node.slug
      const frontmatter = frontmatterCache.get(slug)
      return frontmatter?.sortorder ?? null
    }

    const aSortOrder = getSortOrder(a)
    const bSortOrder = getSortOrder(b)

    // Handle folder vs file sorting first
    if ((!a.isFolder && !b.isFolder) || (a.isFolder && b.isFolder)) {
      // Both are files or both are folders
      if (aSortOrder !== null && bSortOrder !== null) {
        // Both have sortorder
        return aSortOrder - bSortOrder
      } else if (aSortOrder !== null && bSortOrder === null) {
        // Only a has sortorder, a comes first
        return -1
      } else if (aSortOrder === null && bSortOrder !== null) {
        // Only b has sortorder, b comes first
        return 1
      } else {
        // Neither has sortorder, sort alphabetically
        return a.displayName.localeCompare(b.displayName, undefined, {
          numeric: true,
          sensitivity: "base",
        })
      }
    }

    // Handle mixed folder/file sorting
    if (!a.isFolder && b.isFolder) {
      return 1
    } else {
      return -1
    }
  }
}

// Function to fetch frontmatter data for all pages
async function fetchFrontmatterData() {
  try {
    // Fetch the content index which contains basic page data
    const response = await fetch(`${window.location.origin}/static/contentIndex.json`)
    if (!response.ok) {
      console.warn("Could not fetch content index for sortorder data")
      return
    }
    
    const contentIndex = await response.json()
    
    // We need to fetch individual page data to get frontmatter
    // Since Quartz doesn't expose full frontmatter in contentIndex,
    // we'll need to make a request to get the original markdown files
    
    // For now, we'll try to get frontmatter from meta tags if available
    // or implement a custom solution
    
    // Try to get frontmatter from the current page's meta tags as an example
    const currentPageMeta = document.querySelector('meta[name="frontmatter"]')
    if (currentPageMeta) {
      try {
        const frontmatter = JSON.parse(currentPageMeta.getAttribute('content') || '{}')
        const currentSlug = window.location.pathname.replace(/\/$/, '') || '/index'
        frontmatterCache.set(currentSlug, frontmatter)
      } catch (e) {
        // Ignore parsing errors
      }
    }
    
    // Alternative: try to fetch frontmatter data from a custom endpoint
    // This would require adding a custom emitter to expose frontmatter data
    try {
      const frontmatterResponse = await fetch(`${window.location.origin}/static/frontmatterIndex.json`)
      if (frontmatterResponse.ok) {
        const frontmatterIndex = await frontmatterResponse.json()
        // Cache all frontmatter data
        for (const [slug, data] of Object.entries(frontmatterIndex)) {
          frontmatterCache.set(slug, data)
        }
      }
    } catch (e) {
      // Frontmatter index doesn't exist yet, that's ok
      console.log("No frontmatter index found, using fallback sorting")
    }
    
  } catch (error) {
    console.warn("Error fetching frontmatter data:", error)
  }
}

async function setupExplorer(currentSlug: FullSlug) {
  // Fetch frontmatter data first
  await fetchFrontmatterData()
  
  const allExplorers = document.querySelectorAll("div.explorer") as NodeListOf<HTMLElement>

  for (const explorer of allExplorers) {
    const dataFns = JSON.parse(explorer.dataset.dataFns || "{}")
    const opts: ParsedOptions = {
      folderClickBehavior: (explorer.dataset.behavior || "collapse") as "collapse" | "link",
      folderDefaultState: (explorer.dataset.collapsed || "collapsed") as "collapsed" | "open",
      useSavedState: explorer.dataset.savestate === "true",
      order: dataFns.order || ["filter", "map", "sort"],
      sortFn: createCustomSortFn(), // Use our custom sort function
      filterFn: new Function("return " + (dataFns.filterFn || "undefined"))(),
      mapFn: new Function("return " + (dataFns.mapFn || "undefined"))(),
    }

    // Get folder state from local storage
    const storageTree = localStorage.getItem("fileTree")
    const serializedExplorerState = storageTree && opts.useSavedState ? JSON.parse(storageTree) : []
    const oldIndex = new Map<string, boolean>(
      serializedExplorerState.map((entry: FolderState) => [entry.path, entry.collapsed]),
    )

    const data = await fetchData
    const entries = [...Object.entries(data)] as [FullSlug, ContentDetails][]
    const trie = FileTrieNode.fromEntries(entries)

    // Apply functions in order
    for (const fn of opts.order) {
      switch (fn) {
        case "filter":
          if (opts.filterFn) trie.filter(opts.filterFn)
          break
        case "map":
          if (opts.mapFn) trie.map(opts.mapFn)
          break
        case "sort":
          if (opts.sortFn) trie.sort(opts.sortFn)
          break
      }
    }

    // Get folder paths for state management
    const folderPaths = trie.getFolderPaths()
    currentExplorerState = folderPaths.map((path) => {
      const previousState = oldIndex.get(path)
      return {
        path,
        collapsed:
          previousState === undefined ? opts.folderDefaultState === "collapsed" : previousState,
      }
    })

    const explorerUl = explorer.querySelector(".explorer-ul")
    if (!explorerUl) continue

    // Create and insert new content
    const fragment = document.createDocumentFragment()
    for (const child of trie.children) {
      const node = child.isFolder
        ? createFolderNode(currentSlug, child, opts)
        : createFileNode(currentSlug, child)

      fragment.appendChild(node)
    }
    explorerUl.insertBefore(fragment, explorerUl.firstChild)

    // restore explorer scrollTop position if it exists
    const scrollTop = sessionStorage.getItem("explorerScrollTop")
    if (scrollTop) {
      explorerUl.scrollTop = parseInt(scrollTop)
    } else {
      // try to scroll to the active element if it exists
      const activeElement = explorerUl.querySelector(".active")
      if (activeElement) {
        activeElement.scrollIntoView({ behavior: "smooth" })
      }
    }

    // Set up event handlers
    const explorerButtons = explorer.getElementsByClassName(
      "explorer-toggle",
    ) as HTMLCollectionOf<HTMLElement>
    for (const button of explorerButtons) {
      button.addEventListener("click", toggleExplorer)
      window.addCleanup(() => button.removeEventListener("click", toggleExplorer))
    }

    // Set up folder click handlers
    if (opts.folderClickBehavior === "collapse") {
      const folderButtons = explorer.getElementsByClassName(
        "folder-button",
      ) as HTMLCollectionOf<HTMLElement>
      for (const button of folderButtons) {
        button.addEventListener("click", toggleFolder)
        window.addCleanup(() => button.removeEventListener("click", toggleFolder))
      }
    }

    const folderIcons = explorer.getElementsByClassName(
      "folder-icon",
    ) as HTMLCollectionOf<HTMLElement>
    for (const icon of folderIcons) {
      icon.addEventListener("click", toggleFolder)
      window.addCleanup(() => icon.removeEventListener("click", toggleFolder))
    }
  }
}

document.addEventListener("prenav", async () => {
  // save explorer scrollTop position
  const explorer = document.querySelector(".explorer-ul")
  if (!explorer) return
  sessionStorage.setItem("explorerScrollTop", explorer.scrollTop.toString())
})

document.addEventListener("nav", async (e: CustomEventMap["nav"]) => {
  const currentSlug = e.detail.url
  await setupExplorer(currentSlug)

  // if mobile hamburger is visible, collapse by default
  for (const explorer of document.getElementsByClassName("explorer")) {
    const mobileExplorer = explorer.querySelector(".mobile-explorer")
    if (!mobileExplorer) return

    if (mobileExplorer.checkVisibility()) {
      explorer.classList.add("collapsed")
      explorer.setAttribute("aria-expanded", "false")

      document.documentElement.classList.remove("mobile-no-scroll")
    }

    mobileExplorer.classList.remove("hide-until-loaded")
  }
})

window.addEventListener("resize", function () {
  const explorer = document.querySelector(".explorer")
  if (explorer && !explorer.classList.contains("collapsed")) {
    document.documentElement.classList.add("mobile-no-scroll")
    return
  }
})

function setFolderState(folderElement: HTMLElement, collapsed: boolean) {
  return collapsed ? folderElement.classList.remove("open") : folderElement.classList.add("open")
}