import { resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

export const requiredChecks = ['Mac 国产模型导入门禁', '国产模型导入回归', '发布文件检查']

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
  const deadline = Date.now() + 12 * 60 * 1000
  const endpoint = `https://api.github.com/repos/youdaowudao/subdocs/commits/${sha}/check-runs?per_page=100`
  while (Date.now() < deadline) {
    let response
    try {
      response = await request(endpoint, {
        headers: { Accept: 'application/vnd.github+json', 'User-Agent': 'UseGoodAI-release-gate', 'X-GitHub-Api-Version': '2022-11-28' },
        signal: AbortSignal.timeout(15000),
      })
    } catch (error) {
      console.log(`发布门禁暂时无法查询：${error.message}`)
    }
    if (response?.ok) {
      const body = await response.json()
      if (!Array.isArray(body.check_runs)) throw new Error('发布门禁响应缺少检查记录，停止构建。')
      const state = releaseState(body.check_runs, sha)
      if (state.failed.length) throw new Error(`发布门禁未通过：${state.failed.join('、')}。停止发布。`)
      if (state.ready) {
        console.log(`发布门禁通过：${sha} 的三项必需检查全部成功。`)
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
