/**
 * Plugin to add custom stylesheets to the Quartz site.
 * This avoids having to import CSS files directly in components.
 */
import { QuartzComponent, QuartzComponentConstructor, QuartzComponentProps } from "./quartz/components/types"

// Import the stylesheets directly
import extraStyles from "./styles/external-link-override.scss"
import sidebarStyles from "./styles/sidebar-custom.scss"

// Define an empty options interface to match Quartz's pattern
interface Options {}

export const CustomStylesheets: QuartzComponentConstructor<Options> = (opts: Options) => {
  const Component: QuartzComponent = (props: QuartzComponentProps) => {
    // Return an empty div that won't be rendered but allows our CSS to be included
    return null
  }

  // Apply CSS but no JS
  Component.css = extraStyles + "\n" + sidebarStyles
  Component.afterDOMLoaded = undefined

  return Component
}
