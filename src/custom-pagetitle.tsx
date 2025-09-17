import { pathToRoot } from "./quartz/util/path"
import { QuartzComponent, QuartzComponentConstructor, QuartzComponentProps } from "./quartz/components/types"
import { classNames } from "./quartz/util/lang"
import { i18n } from "./quartz/i18n"

const CustomPageTitle: QuartzComponent = ({ fileData, cfg, displayClass }: QuartzComponentProps) => {
  const title = cfg?.pageTitle ?? i18n(cfg.locale).propertyDefaults.title
  const baseDir = pathToRoot(fileData.slug!)
  return (
    <h2 class={classNames(displayClass, "page-title")}>
      <a href={baseDir}>
        <img src="/assets/cesium_logo.png" alt="Cesium Logo" class="page-title-logo" />
        {title}
      </a>
    </h2>
  )
}

CustomPageTitle.css = `
.page-title {
  font-size: 1.75rem;
  margin: 0;
  font-family: var(--titleFont);
}

.page-title a {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  text-decoration: none;
  color: inherit;
}

.page-title-logo {
  height: 4rem;
  width: auto;
}
`

export default (() => CustomPageTitle) satisfies QuartzComponentConstructor
