import assert from 'node:assert/strict'
import { spawn, spawnSync } from 'node:child_process'
import { createServer } from 'node:http'
import { mkdir, mkdtemp, readdir, readFile, rm, stat, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import test from 'node:test'

const publishedPath = new URL('../docs/public/install/helper.ps1', import.meta.url)
const sourcePath = new URL('../usegoodai-codex-installer/install/helper.ps1', import.meta.url)
const exeUrl = 'https://docs.usegoodai.com/download/usegoodai-quick-connect-windows-x64.exe'
const desktopFile = 'UseGoodAI中转快速接入助手.exe'

function findPowerShell() {
  for (const command of ['pwsh', 'powershell']) {
    const result = spawnSync(command, ['-NoProfile', '-Command', 'exit 0'])
    if (result.status === 0) {
      return command
    }
  }
  return undefined
}

const powershellCommand = findPowerShell()
const fakeExe = Buffer.concat([Buffer.from('MZ'), Buffer.alloc(2 * 1024 * 1024, 1)])

test('published helper opener matches the installer source', async () => {
  assert.equal(await readFile(publishedPath, 'utf8'), await readFile(sourcePath, 'utf8'))
})

test('helper opener downloads the runnable exe, never the zip, and names the QQ group', async () => {
  const script = await readFile(publishedPath, 'utf8')

  assert.ok(script.includes(`"${exeUrl}"`))
  assert.doesNotMatch(script, /\.zip/)
  assert.match(script, /\$QqGroup = "1020015031"/)
  assert.match(script, /下载失败时，进 QQ 群 \$QqGroup，在群文件下载/)
  assert.match(script, /下载或打开失败/)
  // 在 irm | iex 里 exit 会关掉用户的 PowerShell 窗口。
  assert.doesNotMatch(script, /^\s*exit\b/m)
})

async function withServer(handler, run) {
  const server = createServer(handler)
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve))
  try {
    return await run(`http://127.0.0.1:${server.address().port}`)
  } finally {
    await new Promise((resolve) => server.close(resolve))
  }
}

async function runHelper(base, route, { windows = true } = {}) {
  const home = await mkdtemp(join(tmpdir(), 'helper-test-'))
  try {
    const desktop = join(home, 'Desktop')
    const temp = join(home, 'tmp')
    await mkdir(desktop)
    await mkdir(temp)
    const script = (await readFile(publishedPath, 'utf8')).replace(exeUrl, `${base}${route}`)
    assert.ok(script.includes(`${base}${route}`))
    await writeFile(join(home, 'helper.ps1'), script)
    // 用函数顶替 Start-Process，只记录要打开的文件，测试里不真的启动程序。
    await writeFile(
      join(home, 'run.ps1'),
      "function Start-Process { param([string]$FilePath) Set-Content -LiteralPath $env:TEST_MARKER -Value $FilePath }\n" +
        '. $env:TEST_SCRIPT\n',
    )
    const env = {
      ...process.env,
      HOME: home,
      USERPROFILE: home,
      TMPDIR: temp,
      TEST_MARKER: join(home, 'opened.txt'),
      TEST_SCRIPT: join(home, 'helper.ps1'),
    }
    delete env.OS
    if (windows) {
      env.OS = 'Windows_NT'
    }
    // 必须异步启动：本地假服务器和测试在同一个进程，同步等待会让它无法回应下载请求。
    const result = await new Promise((resolve, reject) => {
      const child = spawn(powershellCommand, ['-NoProfile', '-File', join(home, 'run.ps1')], {
        cwd: home,
        env,
      })
      let stdout = ''
      let stderr = ''
      child.stdout.setEncoding('utf8').on('data', (chunk) => { stdout += chunk })
      child.stderr.setEncoding('utf8').on('data', (chunk) => { stderr += chunk })
      child.on('error', reject)
      child.on('close', (status) => resolve({ status, stdout, stderr }))
    })
    const opened = await readFile(join(home, 'opened.txt'), 'utf8').catch(() => '')
    const desktopFiles = await readdir(desktop)
    const leftovers = await readdir(temp)
    const downloaded = desktopFiles.includes(desktopFile)
      ? await readFile(join(desktop, desktopFile))
      : undefined
    return { result, opened: opened.trim(), desktop, desktopFiles, leftovers, downloaded }
  } finally {
    await rm(home, { recursive: true, force: true })
  }
}

const powershellSkip = powershellCommand === undefined ? 'PowerShell runtime is not installed' : false

test('helper opener puts the exe on the desktop and opens it', { skip: powershellSkip }, async () => {
  await withServer(
    (request, response) => {
      response.writeHead(200, { 'Content-Type': 'application/octet-stream' })
      response.end(fakeExe)
    },
    async (base) => {
      const run = await runHelper(base, '/helper.exe')
      assert.equal(run.result.status, 0, run.result.stderr || run.result.stdout)
      assert.deepEqual(run.desktopFiles, [desktopFile])
      assert.deepEqual(run.downloaded, fakeExe)
      assert.ok(run.opened.endsWith(`Desktop/${desktopFile}`) || run.opened.endsWith(`Desktop\\${desktopFile}`), run.opened)
      assert.match(run.result.stdout, /助手已打开。回网站点「一键导入 Codex」/)
      assert.doesNotMatch(run.result.stdout, /下载或打开失败/)
      assert.deepEqual(run.leftovers, [])
    },
  )
})

test('helper opener refuses a web page and points to the QQ group file', { skip: powershellSkip }, async () => {
  await withServer(
    (request, response) => {
      response.writeHead(200, { 'Content-Type': 'text/html' })
      response.end('<html>登录或错误页面</html>')
    },
    async (base) => {
      const run = await runHelper(base, '/error')
      assert.equal(run.result.status, 0, run.result.stderr || run.result.stdout)
      assert.deepEqual(run.desktopFiles, [])
      assert.equal(run.opened, '')
      assert.match(run.result.stdout, /下载或打开失败：下载到的内容不是助手程序/)
      assert.match(run.result.stdout, /请进 QQ 群 1020015031，在群文件下载「中转站快速导入工具」/)
      assert.deepEqual(run.leftovers, [])
    },
  )
})

test('helper opener refuses a tiny MZ file', { skip: powershellSkip }, async () => {
  await withServer(
    (request, response) => {
      response.writeHead(200)
      response.end(Buffer.from('MZ tiny'))
    },
    async (base) => {
      const run = await runHelper(base, '/tiny.exe')
      assert.deepEqual(run.desktopFiles, [])
      assert.equal(run.opened, '')
      assert.match(run.result.stdout, /下载或打开失败：下载到的内容不是助手程序/)
    },
  )
})

test('helper opener retries once, then shows the error and the QQ group', { skip: powershellSkip }, async () => {
  let requests = 0
  await withServer(
    (request, response) => {
      requests += 1
      response.writeHead(404)
      response.end('missing')
    },
    async (base) => {
      const run = await runHelper(base, '/missing.exe')
      assert.equal(run.result.status, 0, run.result.stderr || run.result.stdout)
      assert.equal(requests, 2)
      assert.deepEqual(run.desktopFiles, [])
      assert.equal(run.opened, '')
      assert.match(run.result.stdout, /第 1 次下载没成功，2 秒后重试/)
      assert.match(run.result.stdout, /下载或打开失败：/)
      assert.match(run.result.stdout, /1020015031/)
      assert.deepEqual(run.leftovers, [])
    },
  )
})

test('helper opener tells Mac users to use the QQ group file', { skip: powershellSkip }, async () => {
  await withServer(
    (request, response) => {
      response.writeHead(200)
      response.end(fakeExe)
    },
    async (base) => {
      const run = await runHelper(base, '/helper.exe', { windows: false })
      assert.equal(run.result.status, 0, run.result.stderr || run.result.stdout)
      assert.match(run.result.stdout, /这条命令只能在 Windows 上用。Mac 请进 QQ 群 1020015031/)
      assert.deepEqual(run.desktopFiles, [])
      assert.equal(run.opened, '')
    },
  )
})
