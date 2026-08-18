# GPT Image 2 比例支持验证与教程补充实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 验证本站 `gpt-image-2` 对常见画面比例的真实支持边界，并把“比例如何转换成 `size`、哪些比例不支持”补充到客户教程。

**Architecture:** 先使用当前正式 Go 原生工具对 UseGoodAI 的 `/v1/images/generations` 做一次请求一张的真实矩阵测试，再用本地参数测试确认 GPT Image 2 只接受 `--size WIDTHxHEIGHT`、不接受 Banana 的 `--aspect-ratio`。真实结果脱敏写入 `test-records`，教程只写已验证结论；代码逻辑保持不变，除非测试暴露现有校验错误。

**Tech Stack:** Go 原生生图工具、Go `testing`、Node `node:test`、VitePress Markdown、UseGoodAI Images API。

---

### Task 1: 固定测试规则与输出目录

**Files:**
- Create after real testing: `usegoodai-imagines-tool/test-records/20260818-gpt-image-2-aspect-probe/SUMMARY.json`
- Temporary only: a `mktemp -d` directory outside the repository; remove it after recording dimensions.

- [x] **Step 1: Fix one prompt and one request policy**

Use the same short prompt for every positive case:

```text
测试：白色背景中央一个红色苹果，主体完整，画面边缘清晰。
```

Use `model=gpt-image-2`, `quality=low`, `n=1`, `output_format=png`. Send each case once. Do not add automatic retries or silently change the requested size. If a case gets `429` or `5xx`, mark it as an infrastructure failure and rerun it manually only after recording the first result.

- [x] **Step 2: Create an isolated temporary output directory**

```bash
probe_dir="$(mktemp -d)"
printf '%s\n' "$probe_dir"
```

Do not write probe images to the repository `images/` directory and do not store API responses or API keys in the record.

- [x] **Step 3: Use the installed native tool and fixed endpoint**

Run the binary through the existing `$CODEX_HOME/tools/usegoodai-imagines-tool/` installation. The tool already uses `https://api.usegoodai.com/v1/images/generations`; do not add `--api-key` or `--base-url` to the command.

### Task 2: Run the GPT Image 2 ratio acceptance matrix

**Files:**
- Create: `usegoodai-imagines-tool/test-records/20260818-gpt-image-2-aspect-probe/SUMMARY.json`

- [x] **Step 1: Test the ratios shared with the Banana documentation**

Use the following exact pixel sizes. Every positive case satisfies the current GPT Image 2 minimum-pixel, 16-pixel, and 3:1 checks while keeping the probe output small.

| Ratio label | `--size` | Expected result |
| --- | --- | --- |
| 1:1 | `1024x1024` | accept baseline |
| 3:2 | `1152x768` | accept |
| 2:3 | `768x1152` | accept |
| 3:4 | `768x1024` | accept |
| 4:3 | `1024x768` | accept |
| 4:5 | `768x960` | accept |
| 5:4 | `960x768` | accept |
| 9:16 | `720x1280` | accept |
| 16:9 | `1280x720` | accept |
| 21:9 | `1344x576` | accept |
| 9:21 | `576x1344` | accept |

Run one case with the existing command shape:

```bash
tool_codex_home="${CODEX_HOME:-$HOME/.codex}"
"$tool_codex_home/tools/usegoodai-imagines-tool/usegoodai-imagines-tool" generate \
  --prompt "测试：白色背景中央一个红色苹果，主体完整，画面边缘清晰。" \
  --model gpt-image-2 \
  --size 768x1024 \
  --quality low \
  --output-format png \
  --n 1 \
  --output-name "gpt-image-2-3x4" \
  --output-dir "$probe_dir"
```

Repeat the same command shape for each row, changing only `--size` and `--output-name`.

- [x] **Step 2: Test the GPT Image 2 ratio boundary**

Run these two positive boundary cases:

| Ratio | `--size` | Expected result |
| --- | --- | --- |
| 3:1 | `1536x512` | accept |
| 1:3 | `512x1536` | accept |

These establish the exact maximum long-edge/short-edge ratio allowed by the current implementation.

- [x] **Step 3: Test ratios that Banana supports but GPT Image 2 should reject**

Run these four cases and confirm they fail before a remote image is produced:

| Ratio | `--size` | Expected result |
| --- | --- | --- |
| 4:1 | `2560x640` | reject: ratio exceeds 3:1 |
| 1:4 | `640x2560` | reject: ratio exceeds 3:1 |
| 8:1 | `2560x320` | reject: ratio exceeds 3:1 |
| 1:8 | `320x2560` | reject: ratio exceeds 3:1 |

Record the diagnostic text and confirm no output file was created for each rejection.

- [x] **Step 4: Check the user-facing input forms**

Confirm both forms are rejected locally for GPT Image 2:

```bash
"$tool_codex_home/tools/usegoodai-imagines-tool/usegoodai-imagines-tool" generate \
  --prompt "测试" --model gpt-image-2 --size 3:4

"$tool_codex_home/tools/usegoodai-imagines-tool/usegoodai-imagines-tool" generate \
  --prompt "测试" --model gpt-image-2 --aspect-ratio 3:4
```

The supported user instruction must therefore be translated to a pixel size such as `768x1024`; the literal `3:4` is not sent as the GPT Image 2 `size` value.

- [x] **Step 5: Inspect actual output dimensions and write the sanitized summary**

For each successful PNG, inspect the dimensions with the system `file` command or an equivalent local image reader. Write only the status, requested size, actual width/height, quality, endpoint, and conclusion to `SUMMARY.json`. Do not include Base64, raw response bodies, temporary URLs, or key material.

The summary must state separately:

```json
{
  "size_parameter_supported": true,
  "literal_aspect_ratio_parameter_supported": false,
  "accepted_ratio_labels": ["1:1", "3:2", "2:3", "3:4", "4:3", "4:5", "5:4", "9:16", "16:9", "21:9", "9:21", "3:1", "1:3"],
  "rejected_ratio_labels": ["4:1", "1:4", "8:1", "1:8"]
}
```

Only put a ratio in the accepted list after its real request succeeds. If an expected positive case fails for a transient reason, keep it out of the accepted list until manually rerun.

### Task 3: Add local regression coverage for the parameter contract

**Files:**
- Modify: `usegoodai-imagines-tool/generate_test.go`

- [x] **Step 1: Add accepted ratio-size cases to `TestNativeCLIValidatesImageParameters`**

Keep the existing `validSizes` entries and add these exact values:

```go
"768x1024", "1024x768", "768x960", "960x768",
"720x1280", "1280x720", "1344x576", "576x1344",
"1536x512", "512x1536",
```

The existing loop already calls `parseGenerationOptions` for the default `gpt-image-2` model and is the correct regression boundary. Keep `1024x1024`, 2K, 4K, and `auto` coverage intact.

- [x] **Step 2: Add invalid ratio and invalid form cases**

Add these entries to the existing `invalidArguments` table:

```go
{"--prompt", "x", "--size", "2560x640"},
{"--prompt", "x", "--size", "640x2560"},
{"--prompt", "x", "--size", "2560x320"},
{"--prompt", "x", "--size", "320x2560"},
{"--prompt", "x", "--size", "3:4"},
{"--prompt", "x", "--aspect-ratio", "3:4"},
```

Keep the existing loop that requires every invalid argument list to return an error. Add these focused assertions after that loop so the error contract stays readable:

```go
if _, err := parseGenerationOptions([]string{"--prompt", "x", "--size", "3:4"}); err == nil || !strings.Contains(err.Error(), "WIDTHxHEIGHT") {
    t.Fatalf("ratio text was not rejected as a pixel size: %v", err)
}
if _, err := parseGenerationOptions([]string{"--prompt", "x", "--aspect-ratio", "3:4"}); err == nil || !strings.Contains(err.Error(), "--size") {
    t.Fatalf("GPT Image 2 accepted Banana's aspect-ratio form: %v", err)
}
```

- [x] **Step 3: Run the focused Go tests**

```bash
go test . -run 'TestNativeCLIValidatesImageParameters|TestNativeCLIUsesPerModelCapabilities'
```

Expected result: both targeted tests pass. Then run the full package test:

```bash
go test .
```

### Task 4: Update the customer tutorials from verified results

**Files:**
- Modify: `docs/image-video-group-image.md`
- Modify: `docs/images/image-generation.md`

- [x] **Step 1: Add the operational GPT Image 2 ratio section to the image-tool tutorial**

Place it immediately after the GPT Image 2 parameter-conversion bullets and before the Nano Banana section. State:

```text
GPT Image 2 不使用 Banana 的 `--aspect-ratio`。用户说 3:4 时，转换为 `--size 768x1024`；4:3 使用 `1024x768`；9:16 使用 `720x1280`；16:9 使用 `1280x720`。本站已验证的比例以本节表格为准，比例超过 3:1 的 4:1、1:4、8:1、1:8 不支持。
```

Copy only rows with `status: "accepted"` from `SUMMARY.json` into the tutorial table. Omit any row that remains an infrastructure failure or has not been rerun successfully. Keep the distinction explicit: Banana sends `aspect_ratio`; GPT Image 2 sends pixel `size`.

- [x] **Step 2: Add the API-facing rule to the standalone GPT image API page**

Update the `size` parameter explanation in `docs/images/image-generation.md` with the current constraints: `auto`, dimensions in multiples of 16, each edge at most 3840, long/short ratio at most 3:1, and total pixels between 655,360 and 8,294,400. Add one concise link to the image-tool tutorial for the tested ratio table instead of duplicating the entire matrix.

- [x] **Step 3: Keep unverified combinations out of the tutorial**

Do not write “all ratios supported”. Write “已验证比例” and list the exact pixel examples. Do not claim that every size/ratio combination has been tested merely because the local validator accepts it.

### Task 5: Protect the tutorial contract and finish verification

**Files:**
- Create: `tests/image-tool-gpt-image-2-doc.test.mjs`

- [x] **Step 1: Add documentation assertions**

Create `tests/image-tool-gpt-image-2-doc.test.mjs` with this complete contract test:

```js
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import test from 'node:test'

const source = readFileSync(
  new URL('../docs/image-video-group-image.md', import.meta.url),
  'utf8',
)

test('documents GPT Image 2 pixel-size ratio mapping', () => {
  assert.match(source, /gpt-image-2[\s\S]{0,500}使用 `size`/)
  assert.match(source, /3:4[\s\S]{0,120}`?768x1024`?/)
  assert.match(source, /4:3[\s\S]{0,120}`?1024x768`?/)
  assert.match(source, /9:16[\s\S]{0,120}`?720x1280`?/)
  assert.match(source, /16:9[\s\S]{0,120}`?1280x720`?/)
  assert.match(source, /3:1/)
  assert.match(source, /4:1[\s\S]{0,160}(不支持|不接受|拒绝)/)
  assert.match(source, /images\/image-generation/)
})
```

- [x] **Step 2: Run focused documentation tests and build**

```bash
node --test tests/image-tool-gpt-image-2-doc.test.mjs tests/image-tool-banana-doc.test.mjs
npm run docs:build
git diff --check
```

Expected result: both documentation tests pass, the VitePress build succeeds, and `git diff --check` prints no errors.

- [x] **Step 3: Review the final evidence before publishing**

Check that `SUMMARY.json`, the Go tests, and the two tutorials agree on the same accepted/rejected ratio list. Report four states separately: real upstream accepted, local validator accepted, documented, and not yet verified. Do not publish a ratio that appears only in the code validator.
