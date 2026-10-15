/* Linux adapter: existing Node.js only; the model/config core is shared with macOS. */
function createLinuxIO(home, core) {
    'use strict';
    var fs = require('fs'), path = require('path'), os = require('os');
    var crypto = require('crypto'), child = require('child_process');
    function exists(file) {
        try { fs.lstatSync(file); return true; }
        catch (error) { if (error.code === 'ENOENT') { return false; } throw error; }
    }
    function isFile(file) { return fs.lstatSync(file).isFile(); }
    function read(file) {
        if (!isFile(file)) { throw new Error('文件不存在或不是普通文件。'); }
        return new (require('util').TextDecoder)('utf-8', {fatal: true, ignoreBOM: true}).decode(fs.readFileSync(file));
    }
    function write(file, text) {
        if (exists(file) && !isFile(file)) { throw new Error('目标文件不是普通文件，停止导入。'); }
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
            /* External stderr can contain private config. Report only a fixed message. */
            throw new Error(error.code === 'ETIMEDOUT' ? 'Codex 后端校验超时，原配置未更改。' : 'Codex 后端校验失败，原配置未更改。');
        }
    }
    var io = {
        join: path.join, exists: exists, isFile: isFile, read: read, write: write,
        resolve: function (base, file) {
            if (file === '~' || file.slice(0, 2) === '~/') { file = path.join(os.homedir(), file.slice(1)); }
            return path.resolve(base, file);
        },
        remove: function (file) { fs.rmSync(file, {force: true, recursive: true}); },
        mkdir: function (directory) { fs.mkdirSync(directory, {mode: 448}); },
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
        var message = /^[\u3400-\u9fff]/.test(error.message) ? error.message : '文件格式或系统操作失败。';
        process.stderr.write('导入失败：' + message + ' 软件未关闭。\n');
        process.exitCode = 1;
    }
}

if (typeof module !== 'undefined' && module.exports) {
    module.exports = {createLinuxIO: createLinuxIO, runLinuxInstaller: runLinuxInstaller};
    if (typeof DOMESTIC_CATALOG !== 'undefined') { runLinuxInstaller(process.argv.slice(2), DomesticModels, DOMESTIC_CATALOG); }
}
