import { QuartzTransformerPlugin } from "./quartz/plugins/types"
import rehypePrettyCode, { Options as CodeOptions, Theme as CodeTheme } from "rehype-pretty-code"

interface Theme extends Record<string, CodeTheme> {
  light: CodeTheme
  dark: CodeTheme
}

const defaultOptions: CodeOptions = {
  theme: {
    light: "github-light",
    dark: "github-dark",
  },
  keepBackground: false,
}

export const CustomSyntaxHighlighting: QuartzTransformerPlugin<Partial<CodeOptions>> = (userOpts) => {
  const opts: CodeOptions = { ...defaultOptions, ...userOpts }

  return {
    name: "CustomSyntaxHighlighting",
    htmlPlugins() {
      return [[rehypePrettyCode, opts]]
    },
  }
}
