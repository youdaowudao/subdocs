"""Read-only comparison of user settings; native application additions are reported separately."""
import json
from pathlib import Path
import sys
import tomllib

expected = tomllib.loads(Path(sys.argv[1]).read_text(encoding='utf-8-sig'))
actual = tomllib.loads(Path(sys.argv[2]).read_text(encoding='utf-8-sig'))
changed = []
added = []

def inspect(before, after, path=''):
    for key, value in before.items():
        name = f'{path}.{key}' if path else key
        if key not in after:
            changed.append(name + ':missing')
        elif isinstance(value, dict):
            if not isinstance(after[key], dict):
                changed.append(name + ':type')
            else:
                inspect(value, after[key], name)
        elif type(value) is not type(after[key]) or value != after[key]:
            changed.append(name + ':value')
    for key in after.keys() - before.keys():
        added.append(f'{path}.{key}' if path else key)

inspect(expected, actual)
print(json.dumps(dict(preserved=not changed, changed=changed, applicationAddedPaths=sorted(added))))
