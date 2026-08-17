import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const imageToolDocSource = readFileSync(
  new URL('../docs/image-video-group-image.md', import.meta.url),
  'utf8',
)
const quickStartSource = readFileSync(new URL('../docs/quick-start.md', import.meta.url), 'utf8')
const configSource = readFileSync(new URL('../docs/.vitepress/config.mts', import.meta.url), 'utf8')
const customCssSource = readFileSync(new URL('../docs/.vitepress/theme/custom.css', import.meta.url), 'utf8')
const ccSwitchSource = readFileSync(new URL('../docs/codex-cc-switch.md', import.meta.url), 'utf8')

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
  const customerPath = imageToolDocSource.slice(
    0,
    imageToolDocSource.indexOf('不用一键安装：让 Codex 创建 Python 脚本'),
  )

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
  assert.doesNotMatch(customerPath, /POST https:\/\/api\.usegoodai\.com/)
})

test('documents the verified Nano Banana 2 Responses request contract', () => {
  assert.match(imageToolDocSource, /POST https:\/\/api\.usegoodai\.com\/v1\/responses/)
  assert.match(imageToolDocSource, /请求方法：POST/)
  assert.match(imageToolDocSource, /完整地址：https:\/\/api\.usegoodai\.com\/v1\/responses/)
  assert.match(imageToolDocSource, /Authorization: Bearer <API_KEY>/)
  assert.match(imageToolDocSource, /"stream": false/)
  assert.match(imageToolDocSource, /"type": "input_text"/)
  assert.match(imageToolDocSource, /"type": "input_image"/)
  assert.match(imageToolDocSource, /标准 Base64 编码图片内容/)
  assert.match(imageToolDocSource, /`data:<MIME 类型>;base64,<Base64 内容>`/)
  assert.match(imageToolDocSource, /分辨率测试是在 `1:1` 下完成的，比例测试是在 `1K` 下完成的/)
  assert.match(imageToolDocSource, /已验证的 `image_size`：/)
  assert.match(imageToolDocSource, /已验证的 `aspect_ratio`：/)
  assert.match(imageToolDocSource, /Nano Banana 不使用 `size`、`quality` 或 `output_format`/)
  assert.match(imageToolDocSource, /`n=3` 已完成真实测试并成功返回 3 张图片/)
  assert.match(imageToolDocSource, /PNG、JPEG、WebP 单张参考图均已验证成功/)
  assert.match(imageToolDocSource, /16:9、21:9、9:21/)
  assert.match(imageToolDocSource, /上面的“改背景”请求已经验证成功/)
  assert.match(imageToolDocSource, /2 张不同参考图和 4 张不同参考图放在同一个请求中均已验证成功/)
  assert.match(imageToolDocSource, /Nano Banana 改图不使用另一个接口/)
  assert.match(imageToolDocSource, /Responses 请求体不发送顶层 `n`/)
  assert.match(imageToolDocSource, /只解析 Responses 返回 JSON 的 `output` 字段/)
  assert.match(imageToolDocSource, /14 张参考图.*HTTP 502/)
  assert.doesNotMatch(imageToolDocSource, /最多接收 14 张/)
})

test('keeps the three primary sidebar paths in the requested order and visually numbered', () => {
  assert.match(
    configSource,
    /'quick-start\.md',\s*'codex-cc-switch\.md',\s*'image-video-group-image\.md',[\s\S]*?'clients'/,
  )
  assert.match(configSource, /frontmatterTitleFieldName:\s*'sidebarTitle'/)
  assert.match(ccSwitchSource, /^sidebarTitle:\s*CC Switch 接入$/m)
  assert.match(customCssSource, /\.link\[href='\/quick-start\.html'\]::before\s*\{[\s\S]*?content:\s*'1'/)
  assert.match(customCssSource, /\.link\[href='\/codex-cc-switch\.html'\]::before\s*\{[\s\S]*?content:\s*'2'/)
  assert.match(customCssSource, /\.link\[href='\/image-video-group-image\.html'\]::before\s*\{[\s\S]*?content:\s*'3'/)
  assert.match(customCssSource, /\.VPSidebar \.link\[href='\/codex-cc-switch\.html'\] \.text/)
  assert.match(customCssSource, /white-space:\s*nowrap/)
  assert.match(quickStartSource, /\[安装生图工具\]\(\/image-video-group-image\)/)
})
