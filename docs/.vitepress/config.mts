import { defineConfig } from 'vitepress'
import { withSidebar } from 'vitepress-sidebar'

const config = defineConfig({
  title: 'UseGoodAI.com中转站教程',
  description: '中转站各类教程',

  themeConfig: {
    nav: [
        { text: '首页', link: '/' },
        { text: '快速开始', link: '/quick-start' },
        { text: '客户端接入', link: '/clients/' },
        { text: '扩展说明', link: '/external/' },
        { text: '生图', link: '/external/image-generation' },
        { text: '常见错误', link: '/errors/' },
        { text: '模型与分组', link: '/models' }
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
  useFolderTitleFromIndexFile: true,
  useFolderLinkFromIndexFile: true,
  collapsed: false,
  includeRootIndexFile: false,
  includeFolderIndexFile: false,
  manualSortFileNameByPriority: [
    'quick-start.md',
    'clients',
    'codex.md',
    'vscode.md',
    'claude-code-desktop.md',
    'cc-switch.md',
    'jetbrains.md',
    'trae.md',
    'infinite-canvas.md',
    'cherry-studio.md',
    'open-webui.md',
    'openclaw.md',
    'hermes.md',
    'librechat.md',
    'external',
    'base-url.md',
    'compatibility.md',
    'user-agent.md',
    'image-generation.md',
    'codex-cli-internal-commands.md',
    'codex-skills.md',
    'codex-superpowers.md',
    'codex-advanced.md',
    'codex-tools.md',
    'errors',
    'index.md',
    'models.md'
  ]
})
