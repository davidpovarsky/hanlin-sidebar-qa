"""Select a matching Xcode/runtime without switching CoreSimulator through old SDKs."""
import glob
import json
import os
import re
import subprocess
from pathlib import Path

def run(args, developer, timeout=45):
    return subprocess.check_output(args, env=dict(os.environ, DEVELOPER_DIR=developer), text=True, timeout=timeout)

def path_version(path):
    return tuple(int(value) for value in re.findall(r'\d+', Path(path).name))

preferred = '/Applications/Xcode_26.2.0.app'
paths = sorted(glob.glob('/Applications/Xcode*.app'), key=path_version, reverse=True)
if preferred in paths:
    paths.remove(preferred)
    paths.insert(0, preferred)
selected = None
checked = set()
for path in paths:
    developer = str(Path(path) / 'Contents/Developer')
    try:
        sdk = run(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-version'], developer, timeout=20).strip()
        version = tuple(map(int, sdk.split('.')))
        resolved = str(Path(path).resolve())
        if resolved in checked or version[0] < 26:
            continue
        checked.add(resolved)
        print(f'Checking SDK {sdk} and available runtimes with {developer}', flush=True)
        runtimes = json.loads(run(['xcrun', 'simctl', 'list', 'runtimes', '-j'], developer, timeout=60))['runtimes']
        runtime = next((item for item in runtimes if item.get('isAvailable') and 'iOS' in item['name']
                        and item['version'].split('.')[:2] == sdk.split('.')[:2]), None)
        if runtime:
            selected = (version, developer, runtime)
            break
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
        continue
if selected is None:
    raise SystemExit('No installed Xcode has a matching iOS26+ simulator runtime')
version, developer, runtime = selected
family = os.environ.get('DEVICE_FAMILY', 'iphone')
data = json.loads(run(['xcrun', 'simctl', 'list', 'devices', 'available', '-j'], developer))
devices = data['devices'].get(runtime['identifier'], [])
prefix = 'iPhone' if family == 'iphone' else 'iPad'
devices = [item for item in devices if item['name'].startswith(prefix)]
if not devices:
    raise SystemExit(f'No {prefix} simulator in runtime {runtime}')
preferred_devices = ['iPhone 16', 'iPhone 17'] if family == 'iphone' else ['iPad Air 11-inch (M3)', 'iPad Air 11-inch (M2)']
def rank(item):
    return preferred_devices.index(item['name']) if item['name'] in preferred_devices else len(preferred_devices)
device = sorted(devices, key=rank)[0]
values = {
    'DEVELOPER_DIR': developer, 'SIMULATOR_ID': device['udid'],
    'SIMULATOR_NAME': device['name'], 'SIMULATOR_OS': runtime['version'],
    'SDK_VERSION': '.'.join(map(str, version)),
}
with open(os.environ['GITHUB_ENV'], 'a') as out:
    for key, value in values.items():
        out.write(f'{key}={value}\n')
print(json.dumps(values, indent=2), flush=True)
Path(os.environ['RUNNER_TEMP'], 'environment.json').write_text(json.dumps(values, indent=2))
