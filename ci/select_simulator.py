"""Select an installed Xcode with a matching iOS simulator runtime, then a device."""
import glob
import json
import os
import re
import subprocess
from pathlib import Path

def run(args, developer):
    return subprocess.check_output(args, env=dict(os.environ, DEVELOPER_DIR=developer), text=True)

choices = []
for path in glob.glob('/Applications/Xcode*.app'):
    developer = str(Path(path) / 'Contents/Developer')
    try:
        sdk = run(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-version'], developer).strip()
        version = tuple(map(int, sdk.split('.')))
        runtimes = json.loads(run(['xcrun', 'simctl', 'list', 'runtimes', '-j'], developer))['runtimes']
        for runtime in runtimes:
            if runtime.get('isAvailable') and 'iOS' in runtime['name'] and runtime['version'].split('.')[:2] == sdk.split('.')[:2]:
                choices.append((version, developer, runtime))
    except subprocess.CalledProcessError:
        continue
if not choices:
    raise SystemExit('No installed Xcode has a matching iOS simulator runtime')
version, developer, runtime = max(choices, key=lambda item: item[0])
if version[0] < 26:
    raise SystemExit('Window resizing QA requires an installed iPadOS 26+ runtime')
family = os.environ.get('DEVICE_FAMILY', 'iphone')
data = json.loads(run(['xcrun', 'simctl', 'list', 'devices', 'available', '-j'], developer))
devices = data['devices'].get(runtime['identifier'], [])
prefix = 'iPhone' if family == 'iphone' else 'iPad'
devices = [item for item in devices if item['name'].startswith(prefix)]
if not devices:
    raise SystemExit(f'No {prefix} simulator in runtime {runtime}')
preferred = ['iPhone 16', 'iPhone 17'] if family == 'iphone' else ['iPad Air 11-inch (M3)', 'iPad Air 11-inch (M2)']
def rank(item):
    return preferred.index(item['name']) if item['name'] in preferred else len(preferred)
device = sorted(devices, key=rank)[0]
values = {
    'DEVELOPER_DIR': developer,
    'SIMULATOR_ID': device['udid'],
    'SIMULATOR_NAME': device['name'],
    'SIMULATOR_OS': runtime['version'],
    'SDK_VERSION': '.'.join(map(str, version)),
}
with open(os.environ['GITHUB_ENV'], 'a') as out:
    for key, value in values.items():
        out.write(f'{key}={value}\n')
print(json.dumps(values, indent=2))
Path(os.environ['RUNNER_TEMP'], 'environment.json').write_text(json.dumps(values, indent=2))
