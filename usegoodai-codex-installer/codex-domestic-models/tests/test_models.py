#!/usr/bin/env python3
"""Isolated functional checks; all writes stay under tests/.work."""
import copy
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
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
        result = execute(['bash','install/codex-models.sh'])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('macOS', result.stderr)
        result = execute([PWSH,'-NoProfile','-File','install/codex-models.ps1'])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Windows', result.stdout)

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
