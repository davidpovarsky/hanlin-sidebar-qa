"""Validate the built bundle, not just project settings."""
import json
import plistlib
import subprocess
import sys
from pathlib import Path
app = Path(sys.argv[1])
platform = sys.argv[2]
with (app / 'Info.plist').open('rb') as source:
    info = plistlib.load(source)
assert info['UIDeviceFamily'] == [1, 2], info.get('UIDeviceFamily')
assert 'UIRequiresFullScreen' not in info, 'Deprecated fixed-size compatibility flag remains'
assert isinstance(info.get('UILaunchScreen'), dict), 'Missing generated launch screen'
assert info['UIApplicationSceneManifest']['UIApplicationSupportsMultipleScenes'] is True
assert set(info['UISupportedInterfaceOrientations~ipad']) == {
    'UIInterfaceOrientationPortrait', 'UIInterfaceOrientationPortraitUpsideDown',
    'UIInterfaceOrientationLandscapeLeft', 'UIInterfaceOrientationLandscapeRight'
}
assert isinstance(info['UISupportedInterfaceOrientations'], list)
assert info['CFBundleSupportedPlatforms'] == [platform], info.get('CFBundleSupportedPlatforms')
exe = app / info['CFBundleExecutable']
assert exe.is_file()
arch = subprocess.check_output(['lipo', '-archs', str(exe)], text=True).strip()
if platform == 'iPhoneOS':
    assert 'arm64' in arch.split(), arch
else:
    assert {'arm64', 'x86_64'}.intersection(arch.split()), arch
print(json.dumps({
    'bundle': str(app), 'bundleIdentifier': info['CFBundleIdentifier'],
    'families': info['UIDeviceFamily'], 'platform': platform, 'architectures': arch,
    'minimumOS': info['MinimumOSVersion'], 'launchScreen': True,
    'iPadOrientations': info['UISupportedInterfaceOrientations~ipad'],
    'resizableWindowConfiguration': True
}, indent=2))
