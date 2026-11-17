#!/usr/bin/env python3
"""Install the local lock plugin, or restore stock with --rollback."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parent
PLUGIN_ID = json.loads((ROOT / 'plugin/manifest.json').read_text())['id']


def run(*args):
    return subprocess.check_output(args, text=True).strip()


def require_unlocked(require_pam=True):
    status = json.loads(run('omarchy-shell', 'lock', 'status'))
    keys = ('locked', 'requested', 'pending', 'sessionLocked', 'secure', 'authenticating')
    if any(status.get(key) is not False for key in keys):
        raise RuntimeError('Session must be confirmed unlocked before changing plugins')
    if require_pam and status.get('passwordPam') is not True:
        raise RuntimeError('Password PAM must be available before changing plugins')


def wait_for_plugin(present):
    for _ in range(40):
        rows = json.loads(run('omarchy', 'plugin', 'list', '--json'))
        if any(row['id'] == PLUGIN_ID for row in rows) == present:
            return
        time.sleep(0.05)
    raise RuntimeError('Plugin discovery did not finish; stock lock remains selected')


def rollback():
    require_unlocked(require_pam=False)
    run('omarchy', 'plugin', 'disable', PLUGIN_ID)
    require_unlocked(require_pam=False)
    run('omarchy', 'plugin', 'enable', 'omarchy.lock')
    print('Enabled omarchy.lock')


def install():
    require_unlocked()
    source = ROOT / 'plugin'
    run('omarchy', 'plugin', 'validate', str(source))
    config = Path.home() / '.config/omarchy'
    target = config / 'plugins' / PLUGIN_ID
    existed = target.exists()
    if target.is_symlink() or (existed and not target.is_dir()):
        raise RuntimeError('Refusing to replace a symlink or non-directory plugin')
    if existed:
        manifest = json.loads((target / 'manifest.json').read_text())
        if manifest.get('id') != PLUGIN_ID or manifest.get('omarchy', {}).get('clonedFrom') != 'omarchy.lock':
            raise RuntimeError('Existing directory is not this lock plugin')
    backups = Path.home() / '.local/state/omarchy/backups/ethereal-glass-lockscreen'
    backups.mkdir(parents=True, exist_ok=True)
    archive = Path(tempfile.mkdtemp(prefix='install-', dir=backups))
    shutil.copy2(config / 'shell.json', archive / 'shell.json')
    stage = Path(tempfile.mkdtemp(prefix='.ethereal-stage-', dir=config))
    try:
        shutil.copytree(source, stage, dirs_exist_ok=True)
        require_unlocked()
        run('omarchy', 'plugin', 'enable', 'omarchy.lock')
        require_unlocked()
        target.parent.mkdir(parents=True, exist_ok=True)
        if existed:
            os.rename(target, archive / 'plugin')
            # Removing the disabled entry before reload makes cache refresh observable.
            run('omarchy-shell', 'shell', 'reloadPlugins')
            wait_for_plugin(False)
        require_unlocked()
        os.rename(stage, target)
        run('omarchy-shell', 'shell', 'rescanPlugins')
        wait_for_plugin(True)
        require_unlocked()
        run('omarchy', 'plugin', 'enable', PLUGIN_ID)
        require_unlocked()
    except Exception:
        # Never destroy or replace a lock client after the session has locked.
        require_unlocked(require_pam=False)
        run('omarchy', 'plugin', 'enable', 'omarchy.lock')
        raise
    finally:
        if stage.exists():
            shutil.rmtree(stage)
    print(f'Installed {PLUGIN_ID}; backup: {archive}')


if __name__ == '__main__':
    try:
        if sys.argv[1:] == ['--rollback']:
            rollback()
        elif not sys.argv[1:]:
            install()
        else:
            raise RuntimeError('Usage: install.py [--rollback]')
    except (RuntimeError, OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        print(f'ethereal-lock: {error}', file=sys.stderr)
        sys.exit(1)
