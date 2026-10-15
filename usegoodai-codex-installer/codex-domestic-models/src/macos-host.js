/* macOS built-in JavaScript for Automation; no Node installation required. */
ObjC.import('Foundation');
function run(argv) {
    'use strict';
    var fm = $.NSFileManager.defaultManager, utf8 = $.NSUTF8StringEncoding;
    function nativeError(message) { throw new Error(message); }
    function attrs(path) { var error = Ref(); return fm.attributesOfItemAtPathError($(path), error); }
    function exists(path) { return !attrs(path).isNil(); }
    function isFile(path) { var value = attrs(path); return !value.isNil() && ObjC.unwrap(value.objectForKey($.NSFileType)) === ObjC.unwrap($.NSFileTypeRegular); }
    function read(path) {
        if (!isFile(path)) { nativeError('文件不存在或不是普通文件。'); }
        var error = Ref(), value = $.NSString.stringWithContentsOfFileEncodingError($(path), utf8, error);
        if (value.isNil()) { nativeError('无法按 UTF-8 读取文件。'); }
        return ObjC.unwrap(value);
    }
    function permissions(path) {
        var error = Ref();
        if (!fm.setAttributesOfItemAtPathError($.NSDictionary.dictionaryWithObjectForKey($(384), $.NSFilePosixPermissions), $(path), error)) { nativeError('无法设置文件权限。'); }
    }
    function write(path, text) {
        var error = Ref();
        if (!$(text).writeToFileAtomicallyEncodingError($(path), true, utf8, error)) { nativeError('无法写入文件。'); }
        permissions(path);
    }
    function remove(path) {
        if (exists(path) && !fm.removeItemAtPathError($(path), Ref())) { nativeError('无法清理暂存文件。'); }
    }
    function execute(executable, args, env) {
        var task = $.NSTask.alloc.init, outputPath = join(env.CODEX_HOME, '.usegoodai-export-' + ObjC.unwrap($.NSUUID.UUID.UUIDString));
        write(outputPath, '');
        var output = $.NSFileHandle.fileHandleForWritingAtPath($(outputPath));
        if (output.isNil()) { nativeError('无法打开校验输出文件。'); }
        task.executableURL = $.NSURL.fileURLWithPath($(executable)); task.arguments = $(args);
        task.standardOutput = output; task.standardError = $.NSFileHandle.fileHandleWithNullDevice;
        task.currentDirectoryURL = $.NSURL.fileURLWithPath($(env.CODEX_HOME));
        var environment = $.NSProcessInfo.processInfo.environment.mutableCopy;
        environment.setObjectForKey($(env.CODEX_HOME), $('CODEX_HOME'));
        task.environment = environment;
        try {
            if (!task.launchAndReturnError(Ref())) { nativeError('无法启动 App 自带的 Codex 后端。'); }
            var deadline = Date.now() + 30000;
            while (task.running && Date.now() < deadline) { $.NSThread.sleepForTimeInterval(0.05); }
            if (task.running) {
                task.terminate;
                $.NSThread.sleepForTimeInterval(0.2);
                if (task.running) {
                    var killer = $.NSTask.alloc.init;
                    killer.executableURL = $.NSURL.fileURLWithPath($('/bin/kill'));
                    killer.arguments = $(['-KILL', String(task.processIdentifier)]);
                    if (!killer.launchAndReturnError(Ref())) { nativeError('无法结束超时的校验后端。'); }
                    killer.waitUntilExit;
                }
                task.waitUntilExit;
                nativeError('App 后端校验超时，原配置未更改。');
            }
            task.waitUntilExit;
            if (task.terminationStatus !== 0) { nativeError('App 后端校验失败，原配置未更改。'); }
            return read(outputPath);
        } finally { output.closeFile; remove(outputPath); }
    }
    var homeValue = $(argv[0]).stringByExpandingTildeInPath.stringByStandardizingPath, executable = argv[1];
    if (!homeValue.isAbsolutePath) { homeValue = fm.currentDirectoryPath.stringByAppendingPathComponent(homeValue).stringByStandardizingPath; }
    var home = ObjC.unwrap(homeValue);
    function resolve(base, path) {
        var value = $(path).stringByExpandingTildeInPath;
        if (!value.isAbsolutePath) { value = $(base).stringByAppendingPathComponent(value); }
        return ObjC.unwrap(value.stringByStandardizingPath);
    }
    function join(a, b) { return ObjC.unwrap($(a).stringByAppendingPathComponent($(b))); }
    var io = {
        join: join, resolve: resolve, read: read, write: write, isFile: isFile, remove: remove,
        exists: exists,
        stamp: function () { return new Date().toISOString().replace(/[^0-9]/g, '') + '.' + ObjC.unwrap($.NSUUID.UUID.UUIDString); },
        mkdir: function (path) {
            if (!fm.createDirectoryAtPathWithIntermediateDirectoriesAttributesError($(path), false, $.NSDictionary.dictionaryWithObjectForKey($(448), $.NSFilePosixPermissions), Ref())) { nativeError('无法创建暂存目录。'); }
        },
        backup: function (from, to) {
            if (!fm.copyItemAtPathToPathError($(from), $(to), Ref())) { nativeError('备份失败，停止导入。'); }
            permissions(to);
        },
        exportAt: function (backend, args, target) { return execute(backend, args, {CODEX_HOME: target}); },
        exportCatalog: function (backend, bundled) { return execute(backend, bundled ? ['debug', 'models', '--bundled'] : ['debug', 'models'], {CODEX_HOME: home}); },
        transaction: function (files, backend, catalogPath, original) {
            DomesticModels.transaction(io, files, backend, home, original);
        }
    };
    try {
        var count = DomesticModels.importModels(io, home, executable, DOMESTIC_CATALOG);
        return '已导入 ' + count + ' 个国产模型，原 GPT 和其他模型已保留。';
    } catch (error) {
        /* Never echo external process stderr, original TOML, or JSON (may contain credentials). */
        throw new Error('导入失败：' + (/^[\u3400-\u9fff]/.test(error.message) ? error.message : '文件格式或系统操作失败，软件未关闭。'));
    }
}
