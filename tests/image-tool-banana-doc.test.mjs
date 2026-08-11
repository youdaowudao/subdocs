import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const imageToolDocSource = readFileSync(
  new URL('../docs/image-video-group-image.md', import.meta.url),
  'utf8',
)
const quickStartSource = readFileSync(new URL('../docs/quick-start.md', import.meta.url), 'utf8')
const configSource = readFileSync(new URL('../docs/.vitepress/config.mts', import.meta.url), 'utf8')

test('puts the image tool installation on one three-step customer path', () => {
  const stepOne = imageToolDocSource.indexOf('## 1. 创建专门画图分组的 API Key')
  const stepTwo = imageToolDocSource.indexOf('## 2. 在终端安装生图工具')
  const stepThree = imageToolDocSource.indexOf('## 3. 打开 Codex 开始生图')

  assert.ok(stepOne > 0)
  assert.ok(stepTwo > stepOne)
  assert.ok(stepThree > stepTwo)
  assert.match(imageToolDocSource, /专门画图分组/)
  assert.match(imageToolDocSource, /\/images\/画图\/画图专用分组\.jpg/)
  assert.match(imageToolDocSource, /irm https:\/\/docs\.usegoodai\.com\/install\/usegoodai-imagines-tool\/install\.ps1 \| iex/)
  assert.match(imageToolDocSource, /curl -fsSL https:\/\/docs\.usegoodai\.com\/install\/usegoodai-imagines-tool\/install\.sh \| bash/)
  assert.match(imageToolDocSource, /已经打开时不用退出应用，直接新建任务/)
  assert.match(imageToolDocSource, /介绍一下中转站生图工具怎么使用，有哪些模型/)
  assert.match(imageToolDocSource, /生成成功后，图片会直接显示在当前 Codex 对话中/)
})

test('keeps secondary information collapsed and retains the DIY Python path at the end', () => {
  assert.ok((imageToolDocSource.match(/<details>/g) || []).length >= 6)
  assert.match(imageToolDocSource, /查看常用说法/)
  assert.match(imageToolDocSource, /查看支持的模型/)
  assert.match(imageToolDocSource, /查看更新、安装位置和卸载方式/)
  assert.match(imageToolDocSource, /安装或生图失败先看这里/)
  const diySection = imageToolDocSource.indexOf('不用一键安装：让 Codex 创建 Python 脚本')
  const troubleshootingSection = imageToolDocSource.indexOf('安装或生图失败先看这里')
  assert.ok(diySection > troubleshootingSection)
  assert.match(imageToolDocSource, /在当前文件夹创建一个可运行的单文件生图脚本/)
  assert.match(imageToolDocSource, /自建 Python 脚本必须遵守的规则/)
  assert.match(imageToolDocSource, /创建或更新当前项目根目录的 AGENTS\.md/)
  assert.doesNotMatch(imageToolDocSource, /POST https:\/\/api\.usegoodai\.com/)
})

test('keeps the image tool as the fourth top-level sidebar entry and links it from quick start', () => {
  assert.match(
    configSource,
    /'quick-start\.md',[\s\S]*?'codex-cc-switch\.md',[\s\S]*?'clients',\s*'image-video-group-image\.md'/,
  )
  assert.match(quickStartSource, /\[安装生图工具\]\(\/image-video-group-image\)/)
})
