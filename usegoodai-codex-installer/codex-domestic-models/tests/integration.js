'use strict';
const fs = require('fs');
const path = require('path');
const cp = require('child_process');
const assert = require('assert/strict');
const core = require('../src/core.js');
const root = path.resolve(__dirname, '..');
const work = path.join(__dirname, '.work', 'js-integration');
const backend = process.env.TEST_CODEX || path.join(root, '.dev-tools/codex/codex-x86_64-unknown-linux-musl');
const domestic = JSON.parse(fs.readFileSync(path.join(__dirname, '.work/domestic.json'), 'utf8'));
fs.mkdirSync(work, {recursive: true});
let assertions = 0;
function check(value) { assert.ok(value); assertions++; }
function host(home, failure) {
    let faulted = false;
    let staged = false;
    const io = {
        join: path.join,
        resolve: (base, input) => path.resolve(base, input),
        exists: file => { try { fs.lstatSync(file); return true; } catch (e) { if (e.code === 'ENOENT') { return false; } throw e; } },
        isFile: file => fs.lstatSync(file).isFile(),
        read: file => fs.readFileSync(file, 'utf8'),
        write(file, text) {
            if (failure === 'write' && !faulted && file === path.join(home, 'usegoodai-models.managed.json')) { faulted = true; throw Error('injected'); }
            const temp = file + '.atomic';
            fs.writeFileSync(temp, text, {mode:0o600}); fs.renameSync(temp, file);
        },
        remove: file => fs.rmSync(file, {force:true, recursive:true}),
        mkdir: dir => fs.mkdirSync(dir, {mode:0o700}),
        stamp: () => 'test.' + require('crypto').randomUUID(),
        backup(from, to) {
            if (failure === 'backup') { throw Error('injected'); }
            fs.copyFileSync(from, to, fs.constants.COPYFILE_EXCL);
        },
        exportAt(exe, args, target) {
            if (target!==home) { staged=true; }
            if (failure === 'validation' && target !== home) { throw Error('injected'); }
            if (failure === 'postcommit' && staged && target === home) { throw Error('injected'); }
            if (failure === 'concurrent' && target !== home) { fs.appendFileSync(path.join(home, 'config.toml'), '# edited externally\n'); }
            const text = cp.execFileSync(exe, args, {cwd:target, env:{...process.env,CODEX_HOME:target}, timeout:30000, encoding:'utf8', stdio:['ignore','pipe','pipe']});
            if (failure === 'wrong_catalog' && target !== home) { return JSON.stringify(domestic); }
            if (failure === 'wrong_metadata' && staged && target === home) { const data=JSON.parse(text); data.models.find(m=>m.slug===domestic.models[0].slug).context_window=42; return JSON.stringify(data); }
            return text;
        },
        exportCatalog: (exe,bundled) => io.exportAt(exe, bundled ? ['debug','models','--bundled'] : ['debug','models'], home),
        transaction: (files,exe,unused,original) => core.transaction(io,files,exe,home,original)
    };
    return io;
}
function setup(name) {
    const home=path.join(work,name+'-'+require('crypto').randomUUID()); fs.mkdirSync(home);
    const exported=JSON.parse(host(home).exportCatalog(backend,true));
    const selected=exported.models.find(m=>m.slug.startsWith('gpt-')).slug;
    const config=`# preserve comments\nmodel = ${JSON.stringify(selected)}\nreview_model = ${JSON.stringify(selected)}\nmodel_provider = "relay"\nmodel_reasoning_effort = "high"\n[model_providers.relay]\nname = "relay"\nbase_url = "https://example.invalid/v1"\nwire_api = "responses"\nrequires_openai_auth = false\n[desktop]\ntheme = "dark"\n`;
    fs.writeFileSync(path.join(home,'config.toml'),config);
    fs.writeFileSync(path.join(home,'auth.json'),'sentinel-do-not-read');
    return {home,config};
}
{
    const {home,config}=setup('success');
    check(core.importModels(host(home),home,backend,domestic)===8);
    const catalog=path.join(home,'usegoodai-models.json');
    let value=JSON.parse(fs.readFileSync(catalog,'utf8'));
    check(value.models.filter(m=>m.slug.startsWith('gpt-')).length>0);
    check(fs.readFileSync(path.join(home,'auth.json'),'utf8')==='sentinel-do-not-read');
    check(fs.readdirSync(home).some(name=>name.startsWith('config.toml.bak.')));
    const gpt=value.models.find(m=>m.slug.startsWith('gpt-')); gpt.custom_metadata={keep:true};
    value.models.find(m=>m.slug===domestic.models[0].slug).obsolete=true;
    const user={...gpt,slug:'user-custom'}; value.models.push(user,{...gpt,slug:'removed-domestic'});
    fs.writeFileSync(catalog,JSON.stringify(value));
    fs.writeFileSync(path.join(home,'usegoodai-models.managed.json'),JSON.stringify([...domestic.models.map(m=>m.slug),'removed-domestic']));
    check(core.importModels(host(home),home,backend,domestic)===8);
    value=JSON.parse(fs.readFileSync(catalog,'utf8'));
    check(!value.models.some(m=>m.slug==='removed-domestic'));
    check(value.models.find(m=>m.slug==='user-custom').custom_metadata.keep);
    check(value.models.find(m=>m.slug===gpt.slug).custom_metadata.keep);
    check(!('obsolete' in value.models.find(m=>m.slug===domestic.models[0].slug)));
    const after=fs.readFileSync(path.join(home,'config.toml'),'utf8');
    core.importModels(host(home),home,backend,domestic);
    check(fs.readFileSync(path.join(home,'config.toml'),'utf8')===after);
    check(config.includes('wire_api = "responses"'));
}
for (const failure of ['write','backup','validation','wrong_catalog','concurrent','postcommit','wrong_metadata']) {
    for (const existing of [false,true]) {
        const {home,config}=setup(failure);
        if (existing) { core.importModels(host(home),home,backend,domestic); }
        const paths=['config.toml','usegoodai-models.json','usegoodai-models.managed.json'];
        const before=paths.map(name=>fs.existsSync(path.join(home,name)) ? fs.readFileSync(path.join(home,name)) : null);
        assert.throws(()=>core.importModels(host(home,failure),home,backend,domestic)); assertions++;
        paths.forEach((name,index)=>{
            const filename=path.join(home,name);
            const actual=fs.existsSync(filename) ? fs.readFileSync(filename) : null;
            const expected=failure==='concurrent' && index===0 ? Buffer.concat([before[index],Buffer.from('# edited externally\n')]) : before[index];
            assert.deepEqual(actual,expected); assertions++;
        });
        check(fs.readFileSync(path.join(home,'auth.json'),'utf8')==='sentinel-do-not-read');
        check(!fs.readdirSync(home).some(name=>name.startsWith('.usegoodai-models-')));
    }
}
{
    const {home}=setup('invalid_toml');
    fs.appendFileSync(path.join(home,'config.toml'),'this is not valid toml\n');
    assert.throws(()=>core.importModels(host(home),home,backend,domestic)); assertions++;
    check(!fs.existsSync(path.join(home,'usegoodai-models.json')));
}
for (const invalid of ['directory','symlink','dangling','managed_directory']) {
    const {home}=setup(invalid);
    const destination=path.join(home,invalid==='managed_directory' ? 'usegoodai-models.managed.json' : 'usegoodai-models.json');
    const linkTarget=path.join(home,'link-target');
    if (invalid==='directory' || invalid==='managed_directory') { fs.mkdirSync(destination); }
    else { if (invalid==='symlink') { fs.writeFileSync(linkTarget,'untouched'); } fs.symlinkSync(linkTarget,destination); }
    const before=fs.readFileSync(path.join(home,'config.toml'));
    assert.throws(()=>core.importModels(host(home),home,backend,domestic)); assertions++;
    assert.deepEqual(fs.readFileSync(path.join(home,'config.toml')),before); assertions++;
    check(fs.lstatSync(destination).isDirectory() || fs.lstatSync(destination).isSymbolicLink());
    if (invalid==='symlink') { check(fs.readFileSync(linkTarget,'utf8')==='untouched'); }
    if (invalid==='dangling') { check(!fs.existsSync(linkTarget)); }
}
{
    const {home}=setup('missing_source');
    fs.appendFileSync(path.join(home,'config.toml'),'\n');
    const filename=path.join(home,'config.toml');
    fs.writeFileSync(filename,'model_catalog_json = "missing.json"\n'+fs.readFileSync(filename,'utf8'));
    check(core.importModels(host(home),home,backend,domestic)===8);
}
{
    const {home}=setup('relative_instructions');
    const filename=path.join(home,'config.toml');
    fs.writeFileSync(path.join(home,'instructions.md'),'Test repository instructions.\n');
    fs.writeFileSync(filename,'model_instructions_file="instructions.md"\n'+fs.readFileSync(filename,'utf8'));
    check(core.importModels(host(home),home,backend,domestic)===8);
    check(fs.readFileSync(filename,'utf8').includes('model_instructions_file="instructions.md"'));
}
console.log(`JavaScript import/rollback: ${assertions} assertions passed`);
