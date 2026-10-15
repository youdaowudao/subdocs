#!/usr/bin/env python3
"""Isolated functional checks; all writes stay under tests/.work."""
import copy
import importlib.util
import json
import os
from pathlib import Path
import shutil
import shlex
import subprocess
import uuid
import tomllib
import unittest

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / 'tests/.work'
WORK.mkdir(exist_ok=True)
spec = importlib.util.spec_from_file_location('build', ROOT / 'build.py')
build = importlib.util.module_from_spec(spec)
spec.loader.exec_module(build)
DOMESTIC = build.build()
(WORK / 'domestic.json').write_text(json.dumps(DOMESTIC, ensure_ascii=False))
NODE = Path(os.environ.get('TEST_NODE', ROOT / '.dev-tools/node/bin/node'))
PWSH = Path(os.environ.get('TEST_PWSH', ROOT / '.dev-tools/pwsh/pwsh'))
CODEX = Path(os.environ.get('TEST_CODEX', ROOT / '.dev-tools/codex/codex-x86_64-unknown-linux-musl'))


def execute(command, **kwargs):
    env = dict(os.environ, CODEX_HOME=str(WORK), NO_COLOR='1', TERM='dumb')
    return subprocess.run([str(x) for x in command], cwd=ROOT, env=env, text=True, capture_output=True, timeout=60, **kwargs)


def model(slug, **updates):
    value = copy.deepcopy(DOMESTIC['models'][0])
    value.update(slug=slug, display_name=slug)
    value.update(updates)
    return value


GPT = model('gpt-original', supported_reasoning_levels=[{'effort': x, 'description': x} for x in ['low', 'medium', 'high', 'xhigh', 'ultra']])
APP = {'models': [GPT, model('gpt-new')], 'version': 12}


def case(config='model = "gpt-original"\nreview_model = "gpt-original"\n', **updates):
    value = dict(config=config, existing=None, app=APP, domestic=DOMESTIC, managed=[], path='/Users/测试/.codex/usegoodai-models.json')
    value.update(updates)
    return copy.deepcopy(value)


CASES = {}
def add(name, value, ok=True):
    CASES[name] = (value, ok)


add('first_import', case())
add('empty_config', case(''))
add('only_comment', case('# existing comment'))
add('preserve_full_objects', case(existing={'models': [model('gpt-original', custom={'nested': ['keep', {'a': True}]}), model('user-custom'), model('Custom'), model('custom')], 'unknown': {'keep': True}}))
add('update_replace_owned', case(existing={'models': [GPT, model('qwen3.8-max', cancelled_field=True), model('removed-domestic'), model('user-custom')]}, managed=['qwen3.8-max', 'removed-domestic']))
add('existing_desktop', case('model="gpt-original"\n[desktop]\nenabled-reasoning-efforts = ["ultra", # keep\n "high",]\ntheme="dark"\n[features]\nx=true\n'))
add('quoted_keys', case('"model_catalog_json" = \'old.json\' # old path\n"model"="gpt-original"\n["desktop"]\n"enabled-reasoning-efforts" = [\'ultra\',\'high\']\n'))
add('dotted_desktop', case('model="gpt-original"\ndesktop.theme="dark"\n[features]\nx=true\n'))
add('dotted_existing', case('model="gpt-original"\ndesktop.enabled-reasoning-efforts=["ultra"] # unchanged comment\n'))
add('nested_desktop', case('model="gpt-original"\n[desktop.extra]\nfoo=true\n'))
add('crlf', case('model="gpt-original"\r\n[desktop]\r\ntheme="dark"\r\n'))
add('no_final_newline', case('model="gpt-original"\n[desktop]'))
add('only_root_no_newline', case('model="gpt-original"'))
add('bom', case('\ufeffmodel="gpt-original"\n'))
add('windows_path', case(path='C:\\Users\\测试\\.codex\\usegoodai-models.json'))
add('path_quotes', case(path='/Users/a"b\\c/.codex/usegoodai-models.json'))
add('multiline_string', case('model="gpt-original"\ninstructions = """\n[desktop]\nmodel_catalog_json = "fake"\n# inside string\n"""\n[features]\nx=true\n'))
add('literal_multiline', case("model=\"gpt-original\"\ninstructions='''\n[desktop]\nmodel_catalog_json='fake'\n'''\n"))
add('multiline_array', case('model="gpt-original"\nother = [\n "#inside",\n "[desktop]",\n]\n'))
add('equals_in_key', case('"custom=key" = "a=b"\nmodel="gpt-original"\n'))
add('unicode_escape', case('model = "gpt-ori\\u0067inal"\n'))
add('escaped_windows_existing_path', case('model="gpt-original"\nmodel_catalog_json="C:\\\\example\\\\config.json"\n'))
add('escaped_unicode_looking_path', case('model="gpt-original"\nmodel_catalog_json="C:\\\\U00000041\\\\models.json"\n'))
add('unicode_large_escape', case('model="gpt-ori\\U00000067inal"\n'))
add('empty_desktop_array', case('[desktop]\nenabled-reasoning-efforts=[]\n'))
add('missing_default', case('model="gpt-missing"\n'), False)
add('missing_review', case('model="gpt-original"\nreview_model="gone"\n'), False)
add('no_gpt', case('model="user-custom"\n', app={'models':[model('user-custom')]}), False)
add('invalid_existing', case(existing={'models':[{'slug':'gpt-old'}]}), False)
add('duplicate_slugs', case(app={'models':[GPT,GPT]}), False)
add('managed_gpt', case(managed=['gpt-original']), False)
add('managed_invalid', case(managed=[123]), False)
add('unknown_effort', case('[desktop]\nenabled-reasoning-efforts=["turbo"]\n'), False)
add('effort_not_array', case('[desktop]\nenabled-reasoning-efforts="high"\n'), False)
add('effort_nonstring', case('[desktop]\nenabled-reasoning-efforts=[123]\n'), False)
add('duplicate_desktop', case('[desktop]\na=1\n[desktop]\nb=2\n'), False)
add('inline_desktop', case('desktop={theme="dark"}\n'), False)
add('profile_catalog_override', case('[profiles.work]\nmodel_catalog_json="elsewhere.json"\n'), False)
add('duplicate_catalog_key', case('model_catalog_json="a"\n"model_catalog_json"="b"\n'), False)
add('unclosed_string', case('a="bad\n'), False)
add('unclosed_multiline', case('a="""\n'), False)
add('unclosed_array', case('a=["bad"\n'), False)


class ModelTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        path = WORK / 'cases.json'
        path.write_text(json.dumps([value for value, _ in CASES.values()], ensure_ascii=False))
        cls.outputs = {}
        for platform, command in [('mac_core', [NODE, 'tests/driver.js', path]), ('windows_core', [PWSH, '-NoProfile', '-File', 'tests/driver.ps1', path])]:
            result = execute(command)
            if result.returncode:
                raise AssertionError(f'{platform}: {result.stderr}')
            cls.outputs[platform] = json.loads(result.stdout)

    def test_platform_parity(self):
        for index, name in enumerate(CASES):
            with self.subTest(name=name):
                left, right = (self.outputs[p][index] for p in ('mac_core', 'windows_core'))
                self.assertEqual(left['ok'], right['ok'])
                if left['ok']:
                    self.assertEqual(left['catalog'], right['catalog'])
                    self.assertEqual(left['efforts'], right['efforts'])
                    self.assertEqual(tomllib.loads(left['config'].lstrip('\ufeff')), tomllib.loads(right['config'].lstrip('\ufeff')))

    def test_cases(self):
        for index, (name, (value, ok)) in enumerate(CASES.items()):
            for platform, outputs in self.outputs.items():
                with self.subTest(name=name, platform=platform):
                    output = outputs[index]
                    self.assertEqual(output['ok'], ok)
                    if not ok:
                        continue
                    parsed = tomllib.loads(output['config'].lstrip('\ufeff'))
                    self.assertEqual(parsed['model_catalog_json'], value['path'])
                    self.assertEqual(len(output['managed']), 8)
                    ids = [x['slug'] for x in output['catalog']['models']]
                    self.assertEqual(len(ids), len(set(ids)))
                    self.assertIn('gpt-original', ids)
                    original = tomllib.loads(value['config'].lstrip('\ufeff'))
                    self.assertEqual(original.get('model_catalog_json'), output['sourcePath'])
                    original.pop('model_catalog_json', None)
                    if 'desktop' in original:
                        original['desktop'].pop('enabled-reasoning-efforts', None)
                        if not original['desktop']:
                            original.pop('desktop')
                    changed = copy.deepcopy(parsed)
                    changed.pop('model_catalog_json')
                    changed['desktop'].pop('enabled-reasoning-efforts')
                    if not changed['desktop']:
                        changed.pop('desktop')
                    self.assertEqual(original, changed)
                    prior = {x['slug']: x for x in (value['existing'] or {'models': []})['models']}
                    result = {x['slug']: x for x in output['catalog']['models']}
                    for slug, item in prior.items():
                        if slug not in value['managed'] and slug not in output['managed']:
                            self.assertEqual(result[slug], item)
                    for item in DOMESTIC['models']:
                        self.assertEqual(result[item['slug']], item)

    def test_exact_ids(self):
        self.assertEqual([m['slug'] for m in DOMESTIC['models']], ['qwen3.8-max','qwen3.8-flash','glm-5.3-flash','deepseek-flash','glm-5.3','kimi-k3','minimax-m3','hy4-preview'])

    def test_embedded_process_functions(self):
        shell, ps = build.parent_process_functions()
        self.assertIn(shell, (ROOT/'install/codex-models.sh').read_text())
        self.assertIn(ps, (ROOT/'install/codex-models.ps1').read_text(encoding='utf-8-sig'))

    def test_generated_scripts_reproducible(self):
        before = {p.name: p.read_bytes() for p in (ROOT/'install').iterdir()}
        build.build()
        self.assertEqual(before, {p.name: p.read_bytes() for p in (ROOT/'install').iterdir()})

    def test_syntax_and_platform_guard(self):
        self.assertEqual(execute(['bash','-n','install/codex-models.sh']).returncode,0)
        result = execute(['/bin/bash','-c','uname() { printf "FreeBSD\\n"; }; export -f uname; exec /bin/bash "$1"','guard','install/codex-models.sh'])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('macOS', result.stderr)
        result = execute([PWSH,'-NoProfile','-File','install/codex-models.ps1'])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Windows', result.stdout)

    def linux_fixture(self, name):
        target=WORK/(name+' 用户 '+uuid.uuid4().hex)
        target.mkdir()
        bundled=json.loads(execute([CODEX,'debug','models','--bundled'],check=True).stdout)
        selected=next(m['slug'] for m in bundled['models'] if m['slug'].startswith('gpt-'))
        original=f'''# preserve existing settings
model = {json.dumps(selected)}
review_model = {json.dumps(selected)}
model_provider = "relay"
model_reasoning_effort = "high"
model_instructions_file = "instructions.md"
[model_providers.relay]
name = "relay"
base_url = "https://example.invalid/v1"
wire_api = "responses"
requires_openai_auth = false
[desktop]
theme = "dark"
'''
        (target/'config.toml').write_text(original)
        (target/'instructions.md').write_text('Test repository instructions.\n')
        (target/'auth.json').write_text('sentinel-do-not-read')
        tools=target/'bin'
        tools.mkdir()
        for name, executable in [('node',NODE),('codex',CODEX)]+[(name,Path(shutil.which(name))) for name in ('uname','awk','id','tr')]:
            (tools/name).symlink_to(executable)
        return target,tools

    def run_linux_script(self, target, tools, backend=None, piped=False, running_backend=None):
        log=target/'mock-kills.log'
        log.write_text('')
        env=dict(os.environ,CODEX_HOME=str(target),PATH=str(tools),LINUX_TEST_KILL_LOG=str(log),NO_COLOR='1')
        wrapper='ps() { :; }; kill() { printf "%s\\n" "$*" >> "$LINUX_TEST_KILL_LOG"; }; export -f ps kill; '
        if running_backend is not None:
            env['LINUX_TEST_APP_BACKEND']=str(running_backend)
            env['LINUX_TEST_USER_UID']=str(os.getuid())
            wrapper+='ps() { if [ "$1" = -axo ]; then printf "7001 1 %s S %s\\n" "$LINUX_TEST_USER_UID" "$LINUX_TEST_APP_BACKEND"; fi; }; readlink() { [ "$1" = /proc/7001/exe ] && printf "%s\\n" "$LINUX_TEST_APP_BACKEND"; }; export -f ps readlink; '
        arguments=['--codex-home',str(target)]
        if backend is not None:arguments+=['--codex-path',str(backend)]
        if piped:
            command=['/bin/bash','-c',wrapper+'exec /bin/bash -s -- "$@"','linux-test',*arguments]
            content=(ROOT/'install/codex-models.sh').read_text()
        else:
            command=['/bin/bash','-c',wrapper+'exec /bin/bash "$@"','linux-test',str(ROOT/'install/codex-models.sh'),*arguments]
            content=None
        return subprocess.run(command,cwd=ROOT,env=env,input=content,text=True,capture_output=True,timeout=60)

    def test_linux_generated_entry_and_pipe_update(self):
        target,tools=self.linux_fixture('linux-entry')
        before=tomllib.loads((target/'config.toml').read_text())
        result=self.run_linux_script(target,tools,CODEX)
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertIn('已导入 8 个国产模型',result.stdout)
        first=json.loads((target/'usegoodai-models.json').read_text())
        gpt=next(m for m in first['models'] if m['slug'].startswith('gpt-'))
        gpt['keep_metadata']={'nested':True}
        custom=copy.deepcopy(gpt);custom['slug']='user-custom'
        removed=copy.deepcopy(gpt);removed['slug']='removed-domestic'
        first['models'] += [custom,removed]
        next(m for m in first['models'] if m['slug']=='qwen3.8-max')['obsolete']=True
        (target/'usegoodai-models.json').write_text(json.dumps(first))
        (target/'usegoodai-models.managed.json').write_text(json.dumps([m['slug'] for m in DOMESTIC['models']]+['removed-domestic']))
        result=self.run_linux_script(target,tools,piped=True)
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        actual=json.loads((target/'usegoodai-models.json').read_text())
        by_id={m['slug']:m for m in actual['models']}
        self.assertNotIn('removed-domestic',by_id)
        self.assertEqual(by_id[gpt['slug']]['keep_metadata'],{'nested':True})
        self.assertEqual(by_id['user-custom'],custom)
        for model in DOMESTIC['models']:self.assertEqual(by_id[model['slug']],model)
        after=tomllib.loads((target/'config.toml').read_text())
        self.assertEqual(Path(after.pop('model_catalog_json')),target/'usegoodai-models.json')
        after['desktop'].pop('enabled-reasoning-efforts')
        self.assertEqual(after,before)
        self.assertEqual((target/'auth.json').read_text(),'sentinel-do-not-read')
        self.assertEqual((target/'mock-kills.log').read_text(),'')
        self.assertTrue(list(target.glob('config.toml.bak.*')))
        for name in ('config.toml','usegoodai-models.json','usegoodai-models.managed.json'):
            self.assertEqual((target/name).stat().st_mode & 0o777,0o600)
        self.assertFalse(list(target.glob('.usegoodai-models-*')))
        self.assertFalse(list(target.glob('.usegoodai-write-*')))

    def test_linux_failed_validation_preserves_config_and_processes(self):
        target,tools=self.linux_fixture('linux-failure')
        config=(target/'config.toml').read_bytes()
        backend=tools/'failing-backend'
        backend.write_text('#!/bin/bash\ncase "$CODEX_HOME" in */.usegoodai-models-*) printf "private-test-value" >&2; exit 1 ;; esac\nexec '+shlex.quote(str(CODEX))+' "$@"\n')
        backend.chmod(0o755)
        result=self.run_linux_script(target,tools,backend)
        self.assertNotEqual(result.returncode,0)
        self.assertNotIn('private-test-value',result.stdout+result.stderr)
        self.assertEqual((target/'config.toml').read_bytes(),config)
        self.assertFalse((target/'usegoodai-models.json').exists())
        self.assertEqual((target/'mock-kills.log').read_text(),'')

    def test_linux_missing_runtime_does_not_write(self):
        target,tools=self.linux_fixture('linux-no-runtime')
        (tools/'node').unlink()
        config=(target/'config.toml').read_bytes()
        result=self.run_linux_script(target,tools,CODEX)
        self.assertNotEqual(result.returncode,0)
        self.assertIn('Node.js',result.stderr)
        self.assertEqual((target/'config.toml').read_bytes(),config)
        self.assertFalse((target/'usegoodai-models.json').exists())
        self.assertEqual((target/'mock-kills.log').read_text(),'')

    def test_linux_missing_codex_does_not_write(self):
        target,tools=self.linux_fixture('linux-no-codex')
        (tools/'codex').unlink()
        config=(target/'config.toml').read_bytes()
        result=self.run_linux_script(target,tools)
        self.assertNotEqual(result.returncode,0)
        self.assertIn('未找到 Codex 后端',result.stderr)
        self.assertEqual((target/'config.toml').read_bytes(),config)
        self.assertFalse((target/'usegoodai-models.json').exists())
        self.assertEqual((target/'mock-kills.log').read_text(),'')

    def test_linux_prefers_running_app_backend(self):
        target,tools=self.linux_fixture('linux-running-app')
        (tools/'codex').unlink()
        (tools/'codex').write_text('#!/bin/bash\nprintf "wrong backend" >&2\nexit 1\n')
        (tools/'codex').chmod(0o755)
        resource_dir=target/'app/resources'
        resource_dir.mkdir(parents=True)
        running_backend=resource_dir/'codex'
        running_backend.symlink_to(CODEX)
        result=self.run_linux_script(target,tools,running_backend=running_backend)
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertIn('已导入 8 个国产模型',result.stdout)
        self.assertEqual((target/'mock-kills.log').read_text().strip(),'-TERM 7001')

    def assert_linux_diagnostic(self, result, target, step, code=None):
        output=result.stdout+result.stderr
        self.assertNotEqual(result.returncode,0)
        self.assertIn('失败步骤：'+step,output)
        self.assertIn('文件或命令：',output)
        self.assertIn('原因：',output)
        self.assertIn('软件未关闭',output)
        self.assertNotIn('文件格式或系统操作失败',output)
        self.assertNotIn('private-credential-do-not-print',output)
        if code:self.assertIn(code,output)
        self.assertEqual((target/'mock-kills.log').read_text(),'')

    def test_linux_json_errors_identify_file_without_contents(self):
        for name,content,step in [
            ('usegoodai-models.managed.json','', '读取并解析已管理模型记录'),
            ('usegoodai-models.managed.json','{"key":"private-credential-do-not-print"', '读取并解析已管理模型记录'),
            ('old-models.json','private-credential-do-not-print', '读取并解析原模型目录'),
        ]:
            with self.subTest(name=name,empty=not content):
                target,tools=self.linux_fixture('linux-json-diagnostic')
                (target/name).write_text(content)
                if name=='old-models.json':
                    config=target/'config.toml'
                    config.write_text('model_catalog_json="old-models.json"\n'+config.read_text())
                before=(target/'config.toml').read_bytes()
                result=self.run_linux_script(target,tools,CODEX)
                self.assert_linux_diagnostic(result,target,step,'EJSON_PARSE')
                self.assertIn(str(target/name),result.stderr)
                self.assertEqual((target/'config.toml').read_bytes(),before)
                self.assertFalse((target/'usegoodai-models.json').exists())

    def test_linux_invalid_utf8_identifies_config(self):
        target,tools=self.linux_fixture('linux-utf8-diagnostic')
        config=target/'config.toml'
        data=config.read_bytes()+b'\xffprivate-credential-do-not-print'
        config.write_bytes(data)
        result=self.run_linux_script(target,tools,CODEX)
        self.assert_linux_diagnostic(result,target,'读取 Codex 配置','ERR_ENCODING_INVALID_ENCODED_DATA')
        self.assertIn(str(config),result.stderr)
        self.assertEqual(config.read_bytes(),data)

    def test_linux_filesystem_errors_identify_operation(self):
        target,tools=self.linux_fixture('linux-path-diagnostic')
        (target/'not-directory').write_text('private-credential-do-not-print')
        config=target/'config.toml'
        config.write_text('model_catalog_json="not-directory/models.json"\n'+config.read_text())
        before=config.read_bytes()
        result=self.run_linux_script(target,tools,CODEX)
        self.assert_linux_diagnostic(result,target,'读取并解析原模型目录','ENOTDIR')
        self.assertIn(str(target/'not-directory/models.json'),result.stderr)
        self.assertEqual(config.read_bytes(),before)

    @unittest.skipIf(os.getuid()==0,'root bypasses chmod permission restrictions')
    def test_linux_permission_errors_identify_config(self):
        target,tools=self.linux_fixture('linux-permission-diagnostic')
        config=target/'config.toml'
        before=config.read_bytes()
        config.chmod(0o000)
        try:
            result=self.run_linux_script(target,tools,CODEX)
            self.assert_linux_diagnostic(result,target,'读取 Codex 配置','EACCES')
            self.assertIn(str(config),result.stderr)
        finally:config.chmod(0o600)
        self.assertEqual(config.read_bytes(),before)

    def test_linux_backend_json_errors_identify_command(self):
        target,tools=self.linux_fixture('linux-backend-json-diagnostic')
        backend=tools/'bad-json-backend'
        backend.write_text('#!/bin/bash\nprintf "private-credential-do-not-print"\n')
        backend.chmod(0o755)
        before=(target/'config.toml').read_bytes()
        result=self.run_linux_script(target,tools,backend)
        self.assert_linux_diagnostic(result,target,'导出并解析 Codex 内置模型目录','EJSON_PARSE')
        self.assertIn(str(backend)+' debug models --bundled',result.stderr)
        self.assertEqual((target/'config.toml').read_bytes(),before)

    def test_linux_backend_errors_expose_safe_reason_and_exit_code(self):
        target,tools=self.linux_fixture('linux-backend-stderr-diagnostic')
        backend=tools/'failing-toml-backend'
        backend.write_text('#!/bin/bash\nprintf "TOML parse error at line 7, column 9\\napi_key=private-credential-do-not-print\\n" >&2\nexit 7\n')
        backend.chmod(0o755)
        before=(target/'config.toml').read_bytes()
        result=self.run_linux_script(target,tools,backend)
        self.assert_linux_diagnostic(result,target,'导出并解析 Codex 内置模型目录')
        self.assertIn('第 7 行，第 9 列',result.stderr)
        self.assertIn('后端退出码：7',result.stderr)
        self.assertEqual((target/'config.toml').read_bytes(),before)

    def test_linux_internal_error_reports_location_without_message(self):
        source='''const core=require('./src/core.js');
const error=new TypeError('private-credential-do-not-print');
error.importStep='测试内部异常'; error.importTarget='/tmp/example-models.json';
error.stack='TypeError: private-credential-do-not-print\\n    at test ([stdin]:12:34)';
console.log(core.formatError(error));'''
        result=execute([NODE,'-e',source])
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertIn('失败步骤：测试内部异常',result.stdout)
        self.assertIn('TypeError',result.stdout)
        self.assertIn('[stdin]:12:34',result.stdout)
        self.assertNotIn('private-credential-do-not-print',result.stdout)

    def test_actual_codex_deserializes_metadata(self):
        target=WORK/'actual-codex'
        target.mkdir(exist_ok=True)
        original=execute([CODEX,'debug','models','--bundled'],check=True)
        data=json.loads(original.stdout)
        gpt=[m for m in data['models'] if m['slug'].startswith('gpt-')]
        self.assertTrue(gpt)
        data['models'] += DOMESTIC['models']
        catalog=target/'models.json'
        catalog.write_text(json.dumps(data,ensure_ascii=False))
        (target/'config.toml').write_text('model_catalog_json = '+json.dumps(str(catalog))+'\n')
        env=dict(os.environ,CODEX_HOME=str(target))
        result=subprocess.run([str(CODEX),'debug','models'],cwd=target,env=env,text=True,capture_output=True,timeout=30)
        self.assertEqual(result.returncode,0,result.stderr)
        loaded=json.loads(result.stdout)
        self.assertEqual([m['slug'] for m in loaded['models']], [m['slug'] for m in data['models']])

    def test_javascript_import_and_rollback(self):
        result=execute([NODE,'tests/integration.js'])
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        print(result.stdout.strip())

    def test_powershell_import_and_rollback(self):
        result=execute([PWSH,'-NoProfile','-File','tests/integration.ps1','-Backend',CODEX,'-DomesticPath',WORK/'domestic.json','-WorkRoot',WORK/'ps-integration'])
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        print(result.stdout.strip())

    def test_powershell_processes(self):
        result=execute([PWSH,'-NoProfile','-File','tests/processes.ps1','-GeneratedScript',ROOT/'install/codex-models.ps1'])
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        print(result.stdout.strip())

    def test_shell_processes(self):
        functions=build.parent_process_functions()[0]
        fixture='''
function id() { printf '1001\\n'; }
function ps() {
  if [ "$1" = -axo ]; then
    cat <<EOF
$$ $PPID 1001 S /Applications/Codex.app/Contents/MacOS/Codex
$PPID 1 1001 S codex
7001 1 1001 S /Applications/ChatGPT.app/Contents/MacOS/ChatGPT
7002 1 1002 S codex
7003 1 1001 Z codex
7004 1 1001 S codex-helper
7005 1 1001 S /Applications/Codex.app/Contents/Resources/codex
1 0 0 S launchd
EOF
  else
    return 0
  fi
}
function say() { printf '%s\\n' "$*"; }
function sleep() { :; }
function kill() { printf '%s\\n' "$*" >> "$process_log"; }
selection="$(list_running_clients)"
[[ "$selection" == *"$$ codex skip"* ]] || exit 11
[[ "$selection" == *"$PPID codex skip"* ]] || exit 12
[[ "$selection" == *"7001 chatgpt stop"* ]] || exit 13
[[ "$selection" == *"7005 codex stop"* ]] || exit 14
[[ "$selection" != *"7002"* && "$selection" != *"7003"* && "$selection" != *"7004"* ]] || exit 15
stop_running_clients
[ "$codex_running" = true ] && [ "$chatgpt_running" = true ] && [ "$clients_left" = true ] || exit 16
report_running_clients
function list_running_clients() { printf '7001 codex stop\\n'; }
stop_running_clients
[ "$clients_left" = false ] || exit 17
report_running_clients
function list_running_clients() { :; }
stop_running_clients
[ "$codex_running" = false ] && [ "$chatgpt_running" = false ] || exit 18
report_running_clients
function list_running_clients() { printf '7001 codex stop\\n'; }
function client_is_alive() { return 0; }
stop_running_clients
[ "$clients_left" = true ] || exit 19
report_running_clients
'''
        script=WORK/'processes.sh'
        process_log=WORK/'mock-kills.log'
        process_log.write_text('')
        script.write_text('set -euo pipefail\nprocess_log="$1"\n'+functions+'\n'+fixture)
        result=execute(['bash',script,process_log])
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertIn('已自动关闭',result.stdout)
        self.assertIn('未能自动关闭',result.stdout)
        self.assertIn('当前未检测到',result.stdout)
        calls=process_log.read_text().splitlines()
        self.assertTrue(any('-KILL' in call for call in calls))
        for call in calls:
            self.assertTrue(set(call.split()[1:]).issubset({'7001','7005'}))


if __name__ == '__main__':
    unittest.main(verbosity=2)
