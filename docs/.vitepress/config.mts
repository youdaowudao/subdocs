import { defineConfig } from 'vitepress'
import { withSidebar } from 'vitepress-sidebar'

const config = defineConfig({
  title: 'UseGoodAI.com中转站教程',
  description: '中转站各类教程',
  themeConfig: {
    nav: [
        { text: '快速开始', link: '/quick-start' },
        { text: 'Codex', link: '/codex/' },
        { text: 'Claude', link: '/claude/' },
        { text: '国产工具', link: '/domestic/' },
        { text: '其他工具', link: '/clients/' },
        { text: '生图', link: '/images/' },
        { text: '遇到问题', link: '/errors/' },
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
  frontmatterTitleFieldName: 'sidebarTitle',
  useFolderTitleFromIndexFile: true,
  useFolderLinkFromIndexFile: true,
  collapsed: true,
  includeRootIndexFile: false,
  includeFolderIndexFile: false,
  excludeByGlobPattern: ['buy.md', 'models.md', 'radar.md'],
  manualSortFileNameByPriority: [
    'quick-start.md',
    'codex-cc-switch.md',
    'image-video-group-image.md',
    'codex-models.md',
    'models.md',
    'codex',
    'manual-config.md',
    'chatgpt-login.md',
    'commands.md',
    'advanced.md',
    'skills.md',
    'superpowers.md',
    'tools.md',
    'git.md',
    'log-sqlite.md',
    'claude',
    'claude-code.md',
    'desktop.md',
    'domestic',
    'kimi-code.md',
    'qwen-code.md',
    'workbuddy.md',
    'trae.md',
    'cherry-studio.md',
    'clients',
    'vscode.md',
    'jetbrains.md',
    'gemini-cli.md',
    'open-webui.md',
    'librechat.md',
    'openclaw.md',
    'hermes.md',
    'images',
    'infinite-canvas.md',
    'image-generation.md',
    'codex-image.md',
    'params.md',
    'external',
    'base-url.md',
    'compatibility.md',
    'user-agent.md',
    'index.md',
    'errors',
    'contact.md'
  ]
})
