import { resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

export const requiredChecks = ['Mac 国产模型导入门禁', '国产模型导入回归', '发布文件检查']

// 与工具工作流的 paths 保持一致；文档、价格页和图片不触发工具测试。
export const toolReleaseFilters = [
  'usegoodai-codex-installer/**',
  'docs/public/install/**',
  'docs/public/download/**',
  'docs/public/_headers',
  '.github/workflows/**',
  'scripts/require-release-checks.mjs',
  'tests/release-gate.test.mjs',
  'tests/install-*.test.mjs',
  'tests/quick-connect-download.test.mjs',
  'tests/image-tool-release.test.mjs',
  '!**/*.md',
  '!**/*.txt',
  '!**/*.png',
  '!**/*.jpg',
  '!**/*.jpeg',
  '!**/*.svg',
  '!**/*.gif',
  '!**/*.webp',
  '!**/*.ico',
  '!**/*.avif',
]

export function isToolReleasePath(path) {
  if (/\.(?:md|txt|png|jpe?g|svg|gif|webp|ico|avif)$/i.test(path)) return false
  return toolReleaseFilters.filter(pattern => !pattern.startsWith('!')).some(pattern => {
    if (pattern.endsWith('/**')) return path.startsWith(pattern.slice(0, -2))
    const escaped = pattern.split('*').map(part => part.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')).join('[^/]*')
    return new RegExp(`^${escaped}$`).test(path)
  })
}

export function toolReleaseTree(body) {
  if (body.truncated !== false || !Array.isArray(body.tree)) throw new Error('无法完整核实工具文件，停止发布。')
  const files = body.tree.filter(item => item.type !== 'tree' && isToolReleasePath(item.path))
  if (!files.length || files.some(item => !/^[a-f0-9]{40}$/.test(item.sha) || !item.mode || !item.type)) {
    throw new Error('工具文件记录不完整，停止发布。')
  }
  return JSON.stringify(files.map(({ path, mode, type, sha }) => [path, mode, type, sha]).sort())
}

const apiBase = 'https://api.github.com/repos/youdaowudao/subdocs'
const apiHeaders = { Accept: 'application/vnd.github+json', 'User-Agent': 'UseGoodAI-release-gate', 'X-GitHub-Api-Version': '2022-11-28' }

export async function toolCheckCommit(sha, request) {
  const get = async path => {
    const response = await request(`${apiBase}${path}`, { headers: apiHeaders, signal: AbortSignal.timeout(15000) })
    if (!response.ok) throw new Error(`无法核实工具发布记录：HTTP ${response.status}。停止发布。`)
    return response.json()
  }
  const runs = await get('/actions/workflows/tools-release-check.yml/runs?branch=main&per_page=1')
  if (!Array.isArray(runs.workflow_runs)) throw new Error('缺少工具发布记录，停止发布。')
  const previousSha = runs.workflow_runs[0]?.head_sha
  if (!previousSha || previousSha === sha) return sha
  if (!/^[a-f0-9]{40}$/.test(previousSha)) throw new Error('工具发布记录的提交哈希无效，停止发布。')
  const [currentTree, previousTree] = await Promise.all([
    get(`/git/trees/${sha}?recursive=1`),
    get(`/git/trees/${previousSha}?recursive=1`),
  ])
  // 比较完整工具文件内容，避免多提交推送或先前失败的工具改动被后续文档提交绕过。
  return toolReleaseTree(currentTree) === toolReleaseTree(previousTree) ? previousSha : sha
}

export function releaseState(checkRuns, sha) {
  const latest = new Map()
  for (const check of checkRuns) {
    if (check.head_sha !== sha || check.app?.slug !== 'github-actions' || !requiredChecks.includes(check.name)) continue
    if (!latest.has(check.name) || check.id > latest.get(check.name).id) latest.set(check.name, check)
  }
  const failed = requiredChecks.filter(name => {
    const check = latest.get(name)
    return check?.status === 'completed' && check.conclusion !== 'success'
  })
  const pending = requiredChecks.filter(name => {
    const check = latest.get(name)
    return !check || check.status !== 'completed'
  })
  return { failed, pending, ready: failed.length === 0 && pending.length === 0 }
}

export async function requireReleaseChecks(env = process.env, request = fetch) {
  // Preview builds and the checks' own site build do not deploy production.
  if (!['1', 'true'].includes(env.CF_PAGES) || env.CF_PAGES_BRANCH !== 'main') return
  const sha = env.CF_PAGES_COMMIT_SHA
  if (!/^[a-f0-9]{40}$/.test(sha || '')) throw new Error('正式发布缺少有效的提交哈希，停止构建。')
  const checkSha = await toolCheckCommit(sha, request)
  if (checkSha !== sha) console.log(`文档或图片更新，工具文件未变，沿用 ${checkSha} 的工具验证，不运行本次工具门禁。`)
  const deadline = Date.now() + 12 * 60 * 1000
  const endpoint = `${apiBase}/commits/${checkSha}/check-runs?per_page=100`
  while (Date.now() < deadline) {
    let response
    try {
      response = await request(endpoint, {
        headers: apiHeaders,
        signal: AbortSignal.timeout(15000),
      })
    } catch (error) {
      console.log(`发布门禁暂时无法查询：${error.message}`)
    }
    if (response?.ok) {
      const body = await response.json()
      if (!Array.isArray(body.check_runs)) throw new Error('发布门禁响应缺少检查记录，停止构建。')
      const state = releaseState(body.check_runs, checkSha)
      if (state.failed.length) throw new Error(`发布门禁未通过：${state.failed.join('、')}。停止发布。`)
      if (state.ready) {
        console.log(`工具验证通过：${checkSha} 的三项必需检查全部成功。`)
        return
      }
      console.log(`等待当前提交的发布门禁：${state.pending.join('、')}`)
    } else if (response) {
      console.log(`发布门禁查询返回 HTTP ${response.status}，继续等待。`)
    }
    await new Promise(resolve => setTimeout(resolve, 30000))
  }
  throw new Error('发布门禁等待超时，未确认三项检查成功，停止发布。')
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  await requireReleaseChecks()
}
