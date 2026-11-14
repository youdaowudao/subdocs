import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import test from 'node:test'
import { isToolReleasePath, releaseState, requireReleaseChecks, requiredChecks, toolCheckCommit, toolReleaseFilters, toolReleaseTree } from '../scripts/require-release-checks.mjs'

const sha = 'a'.repeat(40)
const check = (name, id, updates = {}) => ({ name, id, head_sha: sha, app: { slug: 'github-actions' }, status: 'completed', conclusion: 'success', ...updates })
const passed = () => requiredChecks.map((name, index) => check(name, index + 1))
const response = body => ({ ok: true, json: async () => body })
const currentRun = response({ workflow_runs: [{ head_sha: sha }] })
const checksRequest = body => async url => url.includes('/actions/workflows/') ? currentRun : response(body)
const tree = files => ({ truncated: false, tree: files.map(([path, object = 'c'.repeat(40)]) => ({ path, mode: '100644', type: 'blob', sha: object })) })
const production = { CF_PAGES: '1', CF_PAGES_BRANCH: 'main', CF_PAGES_COMMIT_SHA: sha }

test('production requires all three successful checks on the exact commit', () => {
  assert.equal(releaseState(passed(), sha).ready, true)
  assert.equal(releaseState(passed().slice(1), sha).ready, false)
  assert.equal(releaseState(passed().map(item => ({ ...item, head_sha: 'b'.repeat(40) })), sha).ready, false)
  assert.equal(releaseState(passed().map(item => ({ ...item, app: { slug: 'another-app' } })), sha).ready, false)
})

test('failed, cancelled and skipped checks cannot release', () => {
  for (const conclusion of ['failure', 'cancelled', 'skipped', 'neutral', 'timed_out']) {
    const runs = passed()
    runs[0].conclusion = conclusion
    assert.deepEqual(releaseState(runs, sha).failed, [requiredChecks[0]])
  }
})

test('queued checks wait, and a newer rerun supersedes an earlier result', () => {
  const runs = passed()
  runs.push(check(requiredChecks[0], 10, { status: 'in_progress', conclusion: null }))
  assert.deepEqual(releaseState(runs, sha).pending, [requiredChecks[0]])
  runs.push(check(requiredChecks[0], 11))
  assert.equal(releaseState(runs, sha).ready, true)
})

test('production fails closed on missing commit, failed checks and malformed responses', async () => {
  const env = { CF_PAGES: '1', CF_PAGES_BRANCH: 'main', CF_PAGES_COMMIT_SHA: sha }
  await assert.rejects(requireReleaseChecks({ ...env, CF_PAGES_COMMIT_SHA: '' }), /提交哈希/)
  const runs = passed()
  runs[1].conclusion = 'failure'
  await assert.rejects(requireReleaseChecks(env, checksRequest({ check_runs: runs })), /未通过/)
  await assert.rejects(requireReleaseChecks(env, checksRequest({})), /缺少检查记录/)
})

test('production accepts verified success; preview and CI builds do not call GitHub', async () => {
  await requireReleaseChecks({ CF_PAGES: '1', CF_PAGES_BRANCH: 'main', CF_PAGES_COMMIT_SHA: sha },
    checksRequest({ check_runs: passed() }))
  const never = async () => { throw Error('unexpected network request') }
  await requireReleaseChecks({}, never)
  await requireReleaseChecks({ CF_PAGES: '1', CF_PAGES_BRANCH: 'preview' }, never)
  const pkg = JSON.parse(await readFile(new URL('../package.json', import.meta.url), 'utf8'))
  for (const command of ['build', 'docs:build']) assert.match(pkg.scripts[command], /^node scripts\/require-release-checks\.mjs && /)
})

test('text, pictures and pricing-page changes do not trigger tool checks', () => {
  for (const path of [
    'CHANGELOG.md', 'docs/contact.md', 'docs/models.md', 'docs/clients/gemini-cli.md',
    'docs/public/images/contact/wechat-group-20261114.png', 'docs/public/brand-icons/gemini.svg',
    'docs/.vitepress/theme/components/model-pricing-data.mjs', 'docs/.vitepress/theme/components/ModelPricing.vue',
    'docs/.vitepress/theme/custom.css', 'tests/model-pricing.test.mjs',
    'usegoodai-codex-installer/README.md', 'usegoodai-codex-installer/test-records/screenshot.jpg',
    'docs/public/download/使用说明.txt',
  ]) assert.equal(isToolReleasePath(path), false, path)
  for (const path of [
    'usegoodai-codex-installer/codex-domestic-models/VERSION',
    'usegoodai-codex-installer/quick-connect/connect/config.go', 'docs/public/install/codex.sh',
    'docs/public/download/usegoodai-tools.zip', 'docs/public/_headers',
    '.github/workflows/tools-release-check.yml', 'scripts/require-release-checks.mjs',
    'tests/release-gate.test.mjs', 'tests/install-codex-models.test.mjs',
  ]) assert.equal(isToolReleasePath(path), true, path)
})

test('push and pull-request filters match the production tool scope', async () => {
  const workflow = await readFile(new URL('../.github/workflows/tools-release-check.yml', import.meta.url), 'utf8')
  const blocks = [...workflow.matchAll(/    paths:\n((?:      - '[^']+'\n)+)/g)]
  assert.equal(blocks.length, 2)
  for (const [, block] of blocks) {
    assert.deepEqual([...block.matchAll(/'([^']+)'/g)].map(([, path]) => path), toolReleaseFilters)
  }
})

test('unchanged tool files reuse the verified tool commit without requesting checks on a documentation commit', async () => {
  const previous = 'b'.repeat(40)
  const calls = []
  const tools = [['scripts/require-release-checks.mjs'], ['docs/public/download/usegoodai-tools.zip']]
  await requireReleaseChecks(production, async url => {
    calls.push(url)
    if (url.includes('/actions/workflows/')) return response({ workflow_runs: [{ head_sha: previous }] })
    if (url.includes(`/git/trees/${sha}`)) return response(tree([...tools, ['docs/contact.md'], ['docs/public/images/contact/wechat-group-20261114.png']]))
    if (url.includes(`/git/trees/${previous}`)) return response(tree([...tools, ['docs/public/images/contact/wetchat.png']]))
    assert.ok(url.includes(`/commits/${previous}/check-runs`))
    return response({ check_runs: passed().map(item => ({ ...item, head_sha: previous })) })
  })
  assert.ok(!calls.some(url => url.includes(`/commits/${sha}/check-runs`)))
})

test('a tool change still requires checks on the new commit, even when followed by documentation changes', async () => {
  const previous = 'b'.repeat(40)
  const result = await toolCheckCommit(sha, async url => {
    if (url.includes('/actions/workflows/')) return response({ workflow_runs: [{ head_sha: previous }] })
    return response(tree([['docs/public/download/usegoodai-tools.zip', url.includes(`/trees/${sha}`) ? 'd'.repeat(40) : 'c'.repeat(40)]]))
  })
  assert.equal(result, sha)
  const oldFiles = tree([['docs/public/install/old.sh']])
  const renamed = tree([['docs/public/install/new.sh']])
  assert.notEqual(toolReleaseTree(oldFiles), toolReleaseTree(renamed))
})

test('documentation cannot bypass a failed tool check or incomplete repository tree', async () => {
  const previous = 'b'.repeat(40)
  const request = async url => {
    if (url.includes('/actions/workflows/')) return response({ workflow_runs: [{ head_sha: previous }] })
    if (url.includes('/git/trees/')) return response(tree([['scripts/require-release-checks.mjs']]))
    return response({ check_runs: passed().map((item, index) => ({ ...item, head_sha: previous, conclusion: index === 0 ? 'failure' : 'success' })) })
  }
  await assert.rejects(requireReleaseChecks(production, request), /未通过/)
  assert.throws(() => toolReleaseTree({ ...tree([['docs/public/install/codex.sh']]), truncated: true }), /完整核实/)
  assert.throws(() => toolReleaseTree({}), /完整核实/)
  await assert.rejects(toolCheckCommit(sha, async () => ({ ok: false, status: 403 })), /HTTP 403/)
})
