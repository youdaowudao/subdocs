/* Linux adapter: existing Node.js only; the model/config core is shared with macOS. */
function createLinuxIO(home, core) {
    'use strict';
    var fs = require('fs'), path = require('path'), os = require('os');
    var crypto = require('crypto'), child = require('child_process');
    function failure(message) { var error = new Error(message); error.safeMessage = message; return error; }
    function exists(file) {
        try { fs.lstatSync(file); return true; }
        catch (error) { if (error.code === 'ENOENT') { return false; } throw error; }
    }
    function isFile(file) { return fs.lstatSync(file).isFile(); }
    function read(file) {
        if (!isFile(file)) { throw failure('文件不存在或不是普通文件。'); }
        return new (require('util').TextDecoder)('utf-8', {fatal: true, ignoreBOM: true}).decode(fs.readFileSync(file));
    }
    function write(file, text) {
        if (exists(file) && !isFile(file)) { throw failure('目标文件不是普通文件，停止导入。'); }
        var temp = path.join(path.dirname(file), '.usegoodai-write-' + crypto.randomUUID());
        try {
            fs.writeFileSync(temp, text, {encoding: 'utf8', flag: 'wx', mode: 384});
            fs.renameSync(temp, file);
        } finally { if (exists(temp)) { fs.unlinkSync(temp); } }
    }
    function exportAt(executable, args, target) {
        try {
            return child.execFileSync(executable, args, {
                cwd: target, env: Object.assign({}, process.env, {CODEX_HOME: target}),
                timeout: 30000, killSignal: 'SIGKILL', maxBuffer: 64 * 1024 * 1024,
                encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe']
            });
        } catch (error) {
            /* Extract known diagnostics, never arbitrary stderr or config excerpts. */
            var reason = 'Codex 后端命令执行失败。';
            var stderr = error.stderr ? String(error.stderr) : '';
            var toml = /TOML parse error at line (\d+), column (\d+)/i.exec(stderr);
            var missing = /missing field [`']([a-z_][a-z0-9_]{0,80})[`']/i.exec(stderr);
            var osError = /os error (\d+)/i.exec(stderr);
            if (error.code === 'ETIMEDOUT') { reason = 'Codex 后端命令执行超过 30 秒。'; }
            else if (error.code === 'ENOENT') { reason = '无法启动 Codex 后端：找不到可执行文件或启动器解释器。'; }
            else if (error.code === 'EACCES') { reason = '无法启动 Codex 后端：没有执行权限。'; }
            else if (toml) { reason = 'Codex 报告 TOML 配置语法错误：第 ' + toml[1] + ' 行，第 ' + toml[2] + ' 列。'; }
            else if (missing) {
                var knownFields = ['slug', 'display_name', 'description', 'supported_reasoning_levels', 'shell_type', 'visibility', 'supported_in_api', 'priority', 'support_verbosity', 'default_verbosity', 'apply_patch_tool_type', 'truncation_policy', 'experimental_supported_tools', 'base_instructions', 'model_messages', 'instructions_template'];
                reason = knownFields.indexOf(missing[1]) >= 0 ? 'Codex 报告模型目录缺少字段：' + missing[1] + '。' : 'Codex 报告模型目录缺少必需字段。';
            }
            else if (/Model provider [`'][^\r\n]*[`'] not found/i.test(stderr)) { reason = 'model_provider 指向的服务名称未在 model_providers 中定义，请核对名称和大小写。'; }
            else if (/unrecognized subcommand|unknown subcommand|unexpected argument|unknown option/i.test(stderr)) { reason = 'Codex 后端未识别模型目录导出命令。'; }
            else if (/failed to read model[_ ]instructions[_ ]file/i.test(stderr)) { reason = 'Codex 无法读取配置中的 model_instructions_file。'; }
            else if (/failed to (?:read|parse) model_catalog_json/i.test(stderr)) { reason = 'Codex 无法读取或解析 model_catalog_json。'; }
            else if (/\b401\b|unauthorized|invalid api key/i.test(stderr)) { reason = 'Codex 后端请求被拒绝：鉴权失败。'; }
            else if (/connection refused|failed to connect|error sending request/i.test(stderr)) { reason = 'Codex 后端连接接口失败。'; }
            else if (osError) { reason = 'Codex 后端报告系统错误，os error ' + osError[1] + '。'; }
            var reported = failure(reason);
            reported.code = error.code; reported.exitStatus = error.status; reported.signal = error.signal;
            throw reported;
        }
    }
    var io = {
        join: path.join, exists: exists, isFile: isFile, read: read, write: write,
        resolve: function (base, file) {
            if (file === '~' || file.slice(0, 2) === '~/') { file = path.join(os.homedir(), file.slice(1)); }
            return path.resolve(base, file);
        },
        remove: function (file) { fs.rmSync(file, {force: true, recursive: true}); },
        mkdir: function (directory, recursive) { fs.mkdirSync(directory, {mode: 448, recursive: !!recursive}); },
        stamp: function () { return new Date().toISOString().replace(/[^0-9]/g, '') + '.' + crypto.randomUUID(); },
        backup: function (from, to) { fs.copyFileSync(from, to, fs.constants.COPYFILE_EXCL); fs.chmodSync(to, 384); },
        exportAt: exportAt,
        exportCatalog: function (backend, bundled) { return exportAt(backend, bundled ? ['debug', 'models', '--bundled'] : ['debug', 'models'], home); },
        transaction: function (files, backend, unused, original) { core.transaction(io, files, backend, home, original); }
    };
    return io;
}

function runLinuxInstaller(argv, core, domestic) {
    'use strict';
    try {
        var path = require('path'), homeArg = argv[0];
        if (homeArg === '~' || homeArg.slice(0, 2) === '~/') { homeArg = path.join(require('os').homedir(), homeArg.slice(1)); }
        var home = path.resolve(homeArg), backend = path.resolve(argv[1]);
        var count = core.importModels(createLinuxIO(home, core), home, backend, domestic);
        process.stdout.write('已导入 ' + count + ' 个国产模型，原 GPT 和其他模型已保留。\n');
    } catch (error) {
        process.stderr.write(core.formatError(error) + '\n软件未关闭。\n');
        process.exitCode = 1;
    }
}

if (typeof module !== 'undefined' && module.exports) {
    module.exports = {createLinuxIO: createLinuxIO, runLinuxInstaller: runLinuxInstaller};
    if (typeof DOMESTIC_CATALOG !== 'undefined') { runLinuxInstaller(process.argv.slice(2), DomesticModels, DOMESTIC_CATALOG); }
}
