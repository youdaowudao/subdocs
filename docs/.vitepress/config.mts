import { defineConfig } from 'vitepress'
import { withSidebar } from 'vitepress-sidebar'

const config = defineConfig({
  title: 'UseGoodAI.com中转站教程',
  description: '中转站各类教程',
  rewrites: {
    'clients/codex-cc-switch.md': 'codex-cc-switch.md',
    'chatgpt-login-usegoodai.md': 'clients/chatgpt-login-usegoodai.md',
    'clients/infinite-canvas.md': 'images/infinite-canvas.md',
    'external/image-generation.md': 'images/image-generation.md',
    'images/codex-image-misunderstanding.md': 'images/codex-image-direct.md'
  },

  themeConfig: {
    nav: [
        { text: '快速开始', link: '/' },
        { text: '一键配置', link: '/quick-start' },
        { text: 'Codex', link: '/clients/codex' },
        { text: '客户端', link: '/clients/' },
        { text: '生图', link: '/images/' },
        { text: '常见错误', link: '/errors/' },
        { text: '联系客服', link: '/contact' }
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
  collapsed: true,
  includeRootIndexFile: false,
  includeFolderIndexFile: false,
  excludeByGlobPattern: ['buy.md'],
  manualSortFileNameByPriority: [
    'quick-start.md',
    'codex-cc-switch.md',
    'models.md',
    'clients',
    'codex.md',
    'chatgpt-login-usegoodai.md',
    'codex-manual-config.md',
    'vscode.md',
    'claude-code-desktop.md',
    'cc-switch.md',
    'jetbrains.md',
    'trae.md',
    'cherry-studio.md',
    'open-webui.md',
    'openclaw.md',
    'hermes.md',
    'librechat.md',
    'images',
    'image-video-group-image.md',
    'infinite-canvas.md',
    'image-generation.md',
    'codex-image-direct.md',
    'codex-image.md',
    'external',
    'base-url.md',
    'compatibility.md',
    'user-agent.md',
    'git-practical.md',
    'codex-cli-internal-commands.md',
    'codex-skills.md',
    'codex-superpowers.md',
    'codex-advanced.md',
    'codex-log-sqlite.md',
    'codex-tools.md',
    'errors',
    'index.md',
    'contact.md'
  ]
})
