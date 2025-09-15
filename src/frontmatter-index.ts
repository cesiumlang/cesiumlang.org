import { QuartzEmitterPlugin } from "./quartz/plugins/types"
import { joinSegments } from "./quartz/util/path"
import { write } from "./quartz/plugins/emitters/helpers"

interface Options {
  // No specific options needed for now
}

const defaultOptions: Options = {}

/**
 * Custom emitter that creates an index of frontmatter and TOC data for all pages
 * This allows the custom Explorer to access sortorder, TOC headers, and other frontmatter fields
 */
export const FrontmatterIndex: QuartzEmitterPlugin<Partial<Options>> = (opts) => {
  opts = { ...defaultOptions, ...opts }
  
  return {
    name: "FrontmatterIndex",
    async *emit(ctx, content) {
      const frontmatterIndex: Record<string, any> = {}
      
      for (const [tree, file] of content) {
        const slug = file.data.slug!
        
        // Extract frontmatter data
        const frontmatter = file.data.frontmatter || {}
        
        // Extract TOC data for navigation tree
        const toc = file.data.toc || []
        
        // Include files that have frontmatter data, TOC data, or both
        if (Object.keys(frontmatter).length > 0 || toc.length > 0) {
          frontmatterIndex[slug] = {
            ...frontmatter,
            toc: toc
          }
        }
      }
      
      // Write the frontmatter index as a JSON file
      const fp = joinSegments("static", "frontmatterIndex")
      yield write({
        ctx,
        content: JSON.stringify(frontmatterIndex),
        slug: fp,
        ext: ".json",
      })
    },
  }
}