/* Pure ES5: used by macOS JXA and the isolated test runner. */
var DomesticModels = (function () {
    'use strict';
    var effortOrder = ['none', 'minimal', 'low', 'medium', 'high', 'xhigh', 'ultra', 'max'];
    function fail(message) { var error = new Error(message); error.safeMessage = message; throw error; }
    function atStep(name, target, action) {
        try { return action(); }
        catch (error) {
            if (!error || typeof error !== 'object') { error = new Error('Unexpected failure'); }
            if (!error.importStep) { error.importStep = name; }
            if (!error.importTarget && target) { error.importTarget = target; }
            throw error;
        }
    }
    function formatError(error) {
        if (!error || typeof error !== 'object') { error = new Error('Unexpected failure'); }
        var messages = {
            EACCES: '权限不足，无法执行该文件操作。', EPERM: '系统拒绝该操作。',
            ENOENT: '文件或目录不存在。', ENOTDIR: '路径中的某一项不是目录。',
            EISDIR: '需要普通文件，实际路径是目录。', ENOSPC: '磁盘空间不足。',
            EROFS: '目标文件系统只读。', EEXIST: '目标路径已经存在。',
            EBUSY: '目标文件被占用，或是不能直接替换的挂载文件。',
            ELOOP: '路径包含循环符号链接。', ENAMETOOLONG: '文件路径过长。',
            ERR_FS_FILE_TOO_LARGE: '文件过大，无法完整读取。',
            EIO: '文件系统读写失败。', EMFILE: '打开的文件过多。',
            ERR_ENCODING_INVALID_ENCODED_DATA: '文件包含无效的 UTF-8 字节。',
            ERR_ACCESS_DENIED: 'Node.js 的运行权限限制拒绝了该操作。'
        };
        var code = error && typeof error.code === 'string' && /^[A-Z][A-Z0-9_]{1,60}$/.test(error.code) ? error.code : '';
        var reason = error.safeMessage || messages[code];
        if (!reason) {
            var kind = ['TypeError', 'ReferenceError', 'RangeError', 'SyntaxError', 'Error'].indexOf(error.name) >= 0 ? error.name : 'Error';
            reason = '脚本内部异常（' + kind + '）。';
        }
        var lines = ['导入失败', '失败步骤：' + (error.importStep || '初始化模型导入')];
        if (error.importTarget) { lines.push('文件或命令：' + error.importTarget); }
        lines.push('原因：' + reason + (code ? ' [' + code + ']' : ''));
        if (typeof error.exitStatus === 'number') { lines.push('后端退出码：' + error.exitStatus); }
        if (error.signal && /^SIG[A-Z0-9]+$/.test(error.signal)) { lines.push('后端信号：' + error.signal); }
        if (!error.safeMessage && !messages[code] && typeof error.stack === 'string') {
            var location = /(?:\[stdin\]|core\.js|linux-host\.js):(\d+):(\d+)/.exec(error.stack);
            if (location) { lines.push('脚本位置：' + location[0]); }
        }
        return lines.join('\n');
    }
    function own(obj, key) { return Object.prototype.hasOwnProperty.call(obj, key); }
    function dict() { return Object.create(null); }
    function canonical(value) {
        if (Array.isArray(value)) { return value.map(canonical); }
        if (value && typeof value === 'object') {
            var result = dict(); Object.keys(value).sort().forEach(function (key) { result[key] = canonical(value[key]); }); return result;
        }
        return value;
    }
    function stringValue(raw) {
        raw = raw.trim();
        if (/^'[^'\r\n]*'$/.test(raw)) { return raw.slice(1, -1); }
        if (/^"(?:[^"\\\r\n]|\\.)*"$/.test(raw)) {
            try {
                return JSON.parse(raw.replace(/\\(?:U[0-9a-fA-F]{8}|e|[\s\S])/g, function (token) {
                    if (token === '\\e') { return '\\u001b'; }
                    if (token.charAt(1) !== 'U' || token.length !== 10) { return token; }
                    var n = parseInt(token.slice(2), 16);
                    if (n > 0x10ffff || (n >= 0xd800 && n <= 0xdfff)) { fail('TOML 路径转义无效。'); }
                    var value = n <= 0xffff ? String.fromCharCode(n) : String.fromCharCode(0xd800 + ((n - 0x10000) >> 10), 0xdc00 + ((n - 0x10000) & 1023));
                    return JSON.stringify(value).slice(1, -1);
                }));
            } catch (e) { fail('TOML 字符串格式无效。'); }
        }
        fail('模型目录、默认模型等目标字段须使用单行 TOML 字符串。');
    }
    function keyParts(raw) {
        var parts = [], pos = 0, m, re = /\s*("(?:[^"\\]|\\.)*"|'[^']*'|[A-Za-z0-9_-]+)\s*/g;
        while (pos < raw.length) {
            re.lastIndex = pos; m = re.exec(raw);
            if (!m || m.index !== pos) { fail('无法识别 TOML 字段或配置段。'); }
            parts.push(/^["']/.test(m[1]) ? stringValue(m[1]) : m[1]);
            pos = re.lastIndex;
            if (pos === raw.length) { break; }
            if (raw.charAt(pos++) !== '.') { fail('TOML 字段路径无效。'); }
        }
        if (!parts.length) { fail('空 TOML 字段。'); }
        return parts;
    }
    function statements(text) {
        var records = [], start = 0, depth = [], quote = '', triple = false, escaped = false, comment = false, clean = '', i, ch, run;
        for (i = 0; i < text.length; i++) {
            ch = text.charAt(i);
            if (comment) {
                if (ch !== '\n') { clean += ' '; continue; }
                comment = false;
            }
            if (quote) {
                clean += ch;
                if (escaped) { escaped = false; continue; }
                if (quote === '"' && ch === '\\') { escaped = true; continue; }
                if (ch === quote) {
                    if (!triple) { quote = ''; }
                    else if (text.substr(i, 3) === quote + quote + quote) {
                        run = 3;
                        while (run < 5 && text.charAt(i + run) === quote) { run++; }
                        clean += text.substr(i + 1, run - 1); i += run - 1; quote = ''; triple = false;
                    }
                } else if (ch === '\n' && !triple) { fail('TOML 字符串未闭合。'); }
                continue;
            }
            if (ch === '#') { comment = true; clean += ' '; continue; }
            if (ch === '"' || ch === "'") {
                quote = ch; triple = text.substr(i, 3) === ch + ch + ch;
                clean += ch;
                if (triple) { clean += ch + ch; i += 2; }
                continue;
            }
            if (ch === '[' || ch === '{') { depth.push(ch); }
            if (ch === ']' || ch === '}') {
                if (depth.pop() !== (ch === ']' ? '[' : '{')) { fail('TOML 括号不匹配。'); }
            }
            clean += ch;
            if (ch === '\n' && !depth.length) { records.push({start: start, end: i + 1, code: clean}); start = i + 1; clean = ''; }
        }
        if (quote || depth.length) { fail('TOML 字符串或括号未闭合。'); }
        if (start < text.length) { records.push({start: start, end: text.length, code: clean}); }
        return records;
    }
    function configInfo(text) {
        var result = {values: dict(), edits: dict(), firstHeader: text.length, desktop: null, desktopInline: false, desktopDotted: false}, scope = [], records = statements(text);
        records.forEach(function (rec) {
            var code = rec.code.trim(), header, eq, parts, path, key, vstart, vend;
            if (!code) { return; }
            if (code.charAt(0) === '[') {
                header = /^(\[\[?)([\s\S]*?)(\]\]?)$/.exec(code);
                if (!header || header[1].length !== header[3].length) { fail('TOML 配置段无效。'); }
                scope = keyParts(header[2].trim());
                result.firstHeader = Math.min(result.firstHeader, rec.start);
                if (scope.join('.') === 'desktop' && scope.length === 1) {
                    if (header[1] === '[[' || result.desktop) { fail('desktop 配置段重复或格式无效。'); }
                    result.desktop = rec;
                }
                return;
            }
            /* '=' inside a quoted key is allowed. */
            var q = '', esc = false;
            for (eq = 0; eq < rec.code.length; eq++) {
                var c = rec.code.charAt(eq);
                if (q) { if (esc) { esc = false; } else if (c === '\\' && q === '"') { esc = true; } else if (c === q) { q = ''; } }
                else if (c === '"' || c === "'") { q = c; }
                else if (c === '=') { break; }
            }
            if (eq === rec.code.length) { fail('TOML 配置行无效。'); }
            parts = keyParts(rec.code.slice(0, eq).trim()); path = scope.concat(parts); key = path.join('.');
            if (!scope.length && parts[0] === 'desktop') {
                result.desktopInline = parts.length === 1;
                result.desktopDotted = parts.length > 1 || result.desktopDotted;
            }
            if (path.length > 1 && path[0] === 'profiles' && path[path.length - 1] === 'model_catalog_json') { fail('profile 中另有 model_catalog_json；请先统一目录配置再导入。'); }
            if ((path.length === 1 && ['model_catalog_json', 'model', 'review_model', 'profile', 'model_provider'].indexOf(key) >= 0) || (path.length === 2 && key === 'desktop.enabled-reasoning-efforts')) {
                if (own(result.edits, key)) { fail('目标 TOML 字段重复。'); }
                vstart = eq + 1;
                while (/\s/.test(rec.code.charAt(vstart)) && vstart < rec.code.length) { vstart++; }
                vend = rec.code.replace(/\s+$/, '').length;
                result.edits[key] = {start: rec.start + vstart, end: rec.start + vend};
                result.values[key] = rec.code.slice(vstart, vend);
            }
        });
        if (result.desktopInline) { fail('desktop 使用内联表；请改为 [desktop] 配置段后导入。'); }
        return result;
    }
    function stringArray(raw) {
        var body = raw.trim(), result = [], parts;
        if (body.charAt(0) !== '[' || body.slice(-1) !== ']') { fail('桌面推理档位必须是字符串数组。'); }
        body = body.slice(1, -1);
        parts = statements('x=[' + body + ']')[0]; // check balanced quotes before splitting
        var re = /\s*("(?:[^"\\]|\\.)*"|'[^']*')\s*(,|$)/g, pos = 0, m;
        while (pos < body.length && body.slice(pos).trim()) {
            re.lastIndex = pos; m = re.exec(body);
            if (!m || m.index !== pos) { fail('桌面推理档位必须是字符串数组。'); }
            result.push(stringValue(m[1])); pos = re.lastIndex;
        }
        return result;
    }
    function patchConfig(text, info, catalogPath, efforts) {
        var newline = text.indexOf('\r\n') >= 0 ? '\r\n' : '\n', changes = [], rootLines = [];
        function set(key, value) {
            if (own(info.edits, key)) { changes.push({start: info.edits[key].start, end: info.edits[key].end, value: value}); return true; }
            return false;
        }
        if (!set('model_catalog_json', JSON.stringify(catalogPath))) { rootLines.push('model_catalog_json = ' + JSON.stringify(catalogPath)); }
        if (!set('desktop.enabled-reasoning-efforts', JSON.stringify(efforts))) {
            var line = 'enabled-reasoning-efforts = ' + JSON.stringify(efforts) + newline;
            if (info.desktop) { changes.push({start: info.desktop.end, end: info.desktop.end, value: (text.charAt(info.desktop.end - 1) === '\n' ? '' : newline) + line}); }
            else if (info.desktopDotted) { rootLines.push('desktop.' + line.trim()); }
            else { changes.push({start: text.length, end: text.length, value: (text && text.slice(-1) !== '\n' ? newline : '') + newline + '[desktop]' + newline + line}); }
        }
        if (rootLines.length) {
            var at = info.firstHeader;
            changes.push({start: at, end: at, value: (at && text.charAt(at - 1) !== '\n' ? newline : '') + rootLines.join(newline) + newline});
        }
        changes.forEach(function (change, index) { change.order = index; });
        changes.sort(function (a, b) { return b.start - a.start || b.end - a.end || a.order - b.order; });
        changes.forEach(function (change) { text = text.slice(0, change.start) + change.value + text.slice(change.end); });
        configInfo(text);
        return text;
    }
    function validateCatalog(catalog) {
        if (!catalog || !Array.isArray(catalog.models) || !catalog.models.length) { fail('模型目录必须包含非空 models 数组。'); }
        var seen = dict();
        catalog.models.forEach(function (model, modelIndex) {
            var location = 'models[' + modelIndex + ']';
            if (!model || typeof model.slug !== 'string' || !model.slug || own(seen, model.slug)) { fail('模型目录 ' + location + '.slug 为空或重复。'); }
            seen[model.slug] = true;
            var invalid = [];
            [['display_name', typeof model.display_name === 'string'], ['supported_reasoning_levels', Array.isArray(model.supported_reasoning_levels)], ['shell_type', Boolean(model.shell_type)], ['visibility', Boolean(model.visibility)], ['supported_in_api', typeof model.supported_in_api === 'boolean'], ['priority', typeof model.priority === 'number'], ['support_verbosity', typeof model.support_verbosity === 'boolean'], ['truncation_policy', Boolean(model.truncation_policy)], ['experimental_supported_tools', Array.isArray(model.experimental_supported_tools)]].forEach(function (field) { if (!field[1]) { invalid.push(field[0]); } });
            if (invalid.length) { fail('模型目录 ' + location + ' 缺少或包含无效字段：' + invalid.join('、') + '。'); }
            if (!(model.model_messages && typeof model.model_messages.instructions_template === 'string') && typeof model.base_instructions !== 'string') { fail('模型目录 ' + location + ' 缺少 model_messages.instructions_template 或 base_instructions。'); }
            model.supported_reasoning_levels.forEach(function (level, index) {
                if (!level || typeof level !== 'object' || typeof level.effort !== 'string' || !level.effort) { fail('模型目录 ' + location + '.supported_reasoning_levels[' + index + '] 缺少有效的 effort。'); }
            });
        });
        return catalog;
    }
    function merge(existing, app, domestic, managed, info) {
        validateCatalog(app); validateCatalog(domestic);
        if (existing) { validateCatalog(existing); }
        if (!Array.isArray(managed) || managed.some(function (x) { return typeof x !== 'string' || !x; })) { fail('已管理模型记录格式无效。'); }
        if (managed.some(function (x) { return /^gpt-/i.test(x); })) { fail('管理记录包含 GPT，停止导入以保留 GPT。'); }
        var byId = dict(), order = [], owned = dict(), result, levels = [], gotGPT = false;
        managed.concat(domestic.models.map(function (x) { return x.slug; })).forEach(function (id) { owned[id] = true; });
        function add(models) { models.forEach(function (model) { if (!own(byId, model.slug) && !own(owned, model.slug)) { byId[model.slug] = model; order.push(model.slug); } }); }
        add(existing ? existing.models : []); add(app.models);
        domestic.models.forEach(function (model) { byId[model.slug] = model; order.push(model.slug); });
        result = JSON.parse(JSON.stringify(existing || app)); result.models = order.map(function (id) { return byId[id]; });
        result.models.forEach(function (model) { if (/^gpt-/i.test(model.slug)) { gotGPT = true; } });
        if (!gotGPT) { fail('未取得 GPT 完整目录，停止导入。'); }
        ['model', 'review_model'].forEach(function (key) {
            if (own(info.values, key) && !own(byId, stringValue(info.values[key]))) { fail('原默认模型或复核模型不在完整目录中，停止导入。'); }
        });
        if (own(info.values, 'desktop.enabled-reasoning-efforts')) { levels = stringArray(info.values['desktop.enabled-reasoning-efforts']); }
        else { result.models.forEach(function (m) { if (/^gpt-/i.test(m.slug)) { m.supported_reasoning_levels.forEach(function (r) { levels.push(r.effort); }); } }); }
        domestic.models.forEach(function (m) { m.supported_reasoning_levels.forEach(function (r) { levels.push(r.effort); }); });
        var unique = dict(); levels.forEach(function (level) { if (effortOrder.indexOf(level) < 0) { fail('桌面档位存在未知值，停止导入。'); } unique[level] = true; });
        return {catalog: validateCatalog(result), efforts: effortOrder.filter(function (level) { return own(unique, level); }), managed: domestic.models.map(function (m) { return m.slug; })};
    }
    function transaction(io, files, backend, home, original) {
        var stamp = io.stamp(), stage = io.join(home, '.usegoodai-models-' + stamp), snapshots = [], committed = [];
        files.forEach(function (file) {
            snapshots.push(atStep('检查并读取写入前的原文件', file.path, function () {
                if (io.exists(file.path) && !io.isFile(file.path)) { fail('目标文件不是普通文件，停止导入。'); }
                return io.exists(file.path) ? io.read(file.path) : null;
            }));
        });
        if (snapshots[2] !== original) { fail('配置在导入过程中被修改，请重新运行。'); }
        atStep('创建私有暂存目录', stage, function () { io.mkdir(stage); });
        try {
            files.forEach(function (file, index) { var target = io.join(stage, 'file-' + index); atStep('写入暂存文件', target, function () { io.write(target, file.text); }); });
            var stagedCatalog = io.join(stage, 'file-0'), info = configInfo(files[2].text);
            var levels = stringArray(info.values['desktop.enabled-reasoning-efforts']);
            atStep('写入校验配置', io.join(stage, 'config.toml'), function () { io.write(io.join(stage, 'config.toml'), 'model_catalog_json = ' + JSON.stringify(stagedCatalog) + '\n[desktop]\nenabled-reasoning-efforts = ' + JSON.stringify(levels) + '\n'); });
            var expected = JSON.stringify(parseJSON(files[0].text).models.map(function (m) { return m.slug; }).sort());
            function verifyAt(target) {
                var validated = atStep(target === home ? '校验实际生效的配置和模型目录' : '校验暂存模型目录', backend + ' debug models', function () { return validateCatalog(parseJSON(io.exportAt(backend, ['debug', 'models'], target))); });
                if (JSON.stringify(validated.models.map(function (m) { return m.slug; }).sort()) !== expected) { fail('App 未读取新模型目录，停止导入。'); }
                return JSON.stringify(canonical(validated.models));
            }
            var normalized = verifyAt(stage);
            files.forEach(function (file, index) {
                atStep('核对导入期间的文件变化', file.path, function () {
                    var now = io.exists(file.path) ? io.read(file.path) : null;
                    if (now !== snapshots[index]) { fail('配置在导入过程中被修改，请重新运行。'); }
                });
            });
            files.forEach(function (file, index) { if (snapshots[index] !== null) { atStep('备份原文件', file.path, function () { io.backup(file.path, file.path + '.bak.' + stamp); }); } });
            files.forEach(function (file, index) { committed.push(index); atStep('提交导入文件', file.path, function () { io.write(file.path, file.text); }); });
            /* Use the original home so relative paths and active profile precedence remain real. */
            if (verifyAt(home) !== normalized) { fail('App 生效的模型元数据与本次导入不一致，停止导入。'); }
        } catch (error) {
            var restoreFailed = false;
            committed.reverse().forEach(function (index) { try { if (snapshots[index] === null) { io.remove(files[index].path); } else { io.write(files[index].path, snapshots[index]); } } catch (ignored) { restoreFailed = true; } });
            if (restoreFailed) { fail('写入失败且恢复未完成，请使用同目录的 .bak 备份恢复；软件未关闭。'); }
            throw error;
        } finally {
            try { io.remove(stage); } catch (ignored) { /* A leftover private stage does not invalidate a successful import. */ }
        }
    }
    function parseJSON(text) {
        try { return JSON.parse(text.replace(/^\uFEFF/, '')); }
        catch (error) {
            var message = !text.trim() ? '内容为空，不是有效的 JSON。' : '内容不是有效的 JSON。';
            var position = /(?:position|offset)\s+(\d+)/i.exec(error.message || '');
            var line = /line\s+(\d+)\s+column\s+(\d+)/i.exec(error.message || '');
            if (position) { message += ' 字符位置：' + position[1] + '。'; }
            if (line) { message += ' 第 ' + line[1] + ' 行，第 ' + line[2] + ' 列。'; }
            error.safeMessage = message; error.code = 'EJSON_PARSE'; throw error;
        }
    }
    function importModels(io, home, executable, domestic) {
        var configPath = io.join(home, 'config.toml'), catalogPath = io.join(home, 'usegoodai-models.json'), managedPath = io.join(home, 'usegoodai-models.managed.json');
        var original = atStep('读取 Codex 配置', configPath, function () {
            if (!io.exists(configPath)) { fail('没有找到 config.toml；请先运行原 GPT 接入脚本。'); }
            return io.read(configPath);
        });
        var info = atStep('解析 Codex 配置', configPath, function () { return configInfo(original); }), existing = null, source, managed = [];
        if (own(info.values, 'model_catalog_json')) {
            source = io.resolve(home, stringValue(info.values.model_catalog_json));
            existing = atStep('读取并解析原模型目录', source, function () { return io.exists(source) ? validateCatalog(parseJSON(io.read(source))) : null; });
        }
        managed = atStep('读取并解析已管理模型记录', managedPath, function () { return io.exists(managedPath) ? parseJSON(io.read(managedPath)) : []; });
        var app = atStep('导出并解析 Codex 内置模型目录', executable + ' debug models --bundled', function () { return validateCatalog(parseJSON(io.exportCatalog(executable, true))); });
        if (!existing) {
            try { existing = validateCatalog(parseJSON(io.exportCatalog(executable, false))); }
            catch (ignored) { /* Missing custom file or unavailable refresh: bundled catalog remains complete. */ }
        }
        var merged = atStep('校验并合并模型元数据', source || executable + ' debug models --bundled', function () { return merge(existing, app, domestic, managed, info); });
        var config = atStep('合并模型目录指向和桌面档位', configPath, function () { return patchConfig(original, info, catalogPath, merged.efforts); });
        var files = [{path: catalogPath, text: JSON.stringify(merged.catalog, null, 2) + '\n'}, {path: managedPath, text: JSON.stringify(merged.managed, null, 2) + '\n'}, {path: configPath, text: config}];
        /* Host stages all files, validates with the selected App backend, then commits with rollback. */
        atStep('写入并校验导入结果', catalogPath, function () { io.transaction(files, executable, catalogPath, original); });
        return merged.managed.length;
    }
    return {statements: statements, configInfo: configInfo, stringValue: stringValue, stringArray: stringArray, patchConfig: patchConfig, validateCatalog: validateCatalog, merge: merge, transaction: transaction, importModels: importModels, formatError: formatError};
}());
if (typeof module !== 'undefined') { module.exports = DomesticModels; }
