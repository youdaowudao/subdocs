import { defineConfig } from 'vitepress'
import { withSidebar } from 'vitepress-sidebar'

const config = defineConfig({
  title: 'UseGoodAI.com中转站教程',
  description: '中转站各类教程',

  themeConfig: {
    nav: [
        { text: '首页', link: '/' },
        { text: '快速开始', link: '/quick-start' },
        { text: '客户端接入', link: '/clients/claude-code' },
        { text: '外接说明', link: '/external/base-url' },
        { text: '常见错误', link: '/errors/403' },
        { text: '模型与分组', link: '/models/groups' }
    ],

     search: {
        provider: 'local'
    }
}

})

export default withSidebar(config, {
  documentRootPath: 'docs',
  useTitleFromFileHeading: true,
  useTitleFromFrontmatter: true,
  collapsed: false,
  includeRootIndexFile: false
})
