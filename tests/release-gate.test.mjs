import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import test from 'node:test'
import { releaseState, requireReleaseChecks, requiredChecks } from '../scripts/require-release-checks.mjs'

const sha = 'a'.repeat(40)
const check = (name, id, updates = {}) => ({ name, id, head_sha: sha, app: { slug: 'github-actions' }, status: 'completed', conclusion: 'success', ...updates })
const passed = () => requiredChecks.map((name, index) => check(name, index + 1))

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
  await assert.rejects(requireReleaseChecks(env, async () => ({ ok: true, json: async () => ({ check_runs: runs }) })), /未通过/)
  await assert.rejects(requireReleaseChecks(env, async () => ({ ok: true, json: async () => ({}) })), /缺少检查记录/)
})

test('production accepts verified success; preview and CI builds do not call GitHub', async () => {
  await requireReleaseChecks({ CF_PAGES: '1', CF_PAGES_BRANCH: 'main', CF_PAGES_COMMIT_SHA: sha },
    async () => ({ ok: true, json: async () => ({ check_runs: passed() }) }))
  const never = async () => { throw Error('unexpected network request') }
  await requireReleaseChecks({}, never)
  await requireReleaseChecks({ CF_PAGES: '1', CF_PAGES_BRANCH: 'preview' }, never)
  const pkg = JSON.parse(await readFile(new URL('../package.json', import.meta.url), 'utf8'))
  for (const command of ['build', 'docs:build']) assert.match(pkg.scripts[command], /^node scripts\/require-release-checks\.mjs && /)
})
