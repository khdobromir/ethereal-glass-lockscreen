import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class InstallTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.project = self.root / 'project'
        self.project.mkdir()
        shutil.copy2(ROOT / 'install.py', self.project / 'install.py')
        shutil.copytree(ROOT / 'plugin', self.project / 'plugin')
        self.home = self.root / 'home'
        config = self.home / '.config/omarchy'
        config.mkdir(parents=True)
        (config / 'shell.json').write_text('{"bar":{"position":"top"}}\n')
        self.target = config / 'plugins/ethereal.lock'
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        for name in ('omarchy', 'omarchy-shell'):
            shutil.copy2(ROOT / 'tests/fake_omarchy.py', self.bin / name)
            (self.bin / name).chmod(0o755)
        self.state_file = self.root / 'state.json'
        self.state_file.write_text(json.dumps({
            'enabled': 'omarchy.lock', 'calls': [],
            'status': {'locked': False, 'requested': False, 'pending': False,
                       'sessionLocked': False, 'secure': False,
                       'authenticating': False, 'passwordPam': True},
        }))
        self.env = dict(os.environ, HOME=str(self.home),
                        PATH=str(self.bin) + os.pathsep + os.environ['PATH'],
                        ETHEREAL_TEST_STATE=str(self.state_file))

    def state(self, **changes):
        state = json.loads(self.state_file.read_text())
        state.update(changes)
        self.state_file.write_text(json.dumps(state))
        return state

    def run_install(self, *args, success=True, optimize=False):
        command = [sys.executable, *(['-O'] if optimize else []), str(self.project / 'install.py'), *args]
        result = subprocess.run(command,
                                env=self.env, capture_output=True, text=True)
        if success:
            self.assertEqual(result.returncode, 0, result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0)
        return result

    def test_fresh_install_copies_and_enables_new_identity(self):
        self.run_install()
        self.assertEqual(json.loads((self.target / 'manifest.json').read_text())['id'], 'ethereal.lock')
        self.assertEqual((self.target / 'Service.qml').read_bytes(),
                         (self.project / 'plugin/Service.qml').read_bytes())
        self.assertEqual(self.state()['enabled'], 'ethereal.lock')
        self.assertFalse((self.target / '.git').exists())

    def test_repeat_install_preserves_previous_files(self):
        self.run_install()
        (self.target / 'previous-local-file').write_text('preserve this')
        (self.project / 'plugin/README.md').write_text('new documentation')
        self.run_install()
        self.assertEqual((self.target / 'README.md').read_text(), 'new documentation')
        archives = list((self.home / '.local/state/omarchy/backups').rglob('previous-local-file'))
        self.assertEqual(len(archives), 1)
        self.assertEqual(archives[0].read_text(), 'preserve this')
        self.assertEqual(self.state()['enabled'], 'ethereal.lock')

    def test_unsafe_or_unknown_state_never_mutates(self):
        for change in ({'locked': True}, {'secure': True}, {'pending': True},
                       {'authenticating': True}, {'passwordPam': False}, {'secure': None}):
            with self.subTest(change=change):
                state = self.state()
                state['status'].update(change)
                self.state(**state)
                self.run_install(success=False)
                self.assertFalse(self.target.exists())
                self.assertFalse((self.home / '.local').exists())
                self.assertFalse(any(c[1:3] in (['plugin', 'enable'], ['plugin', 'disable'])
                                     for c in self.state()['calls']))
                state['status'].update({k: True if k == 'passwordPam' else False for k in change})
                self.state(**state)

    def test_missing_ipc_never_mutates(self):
        self.state(ipcFail=True)
        self.run_install(success=False)
        self.assertFalse(self.target.exists())
        self.assertFalse((self.home / '.local').exists())

    def test_enable_failure_leaves_stock_enabled(self):
        self.state(failEnable=True)
        self.run_install(success=False)
        self.assertEqual(self.state()['enabled'], 'omarchy.lock')

    def test_unavailable_new_pam_restores_stock_while_unlocked(self):
        self.state(failReady=True)
        self.run_install(success=False)
        self.assertEqual(self.state()['enabled'], 'omarchy.lock')

    def test_optimized_python_still_rejects_locked_session(self):
        state = self.state()
        state['status']['locked'] = True
        self.state(**state)
        self.run_install(success=False, optimize=True)
        self.assertFalse(self.target.exists())
        self.assertFalse((self.home / '.local').exists())

    def test_rollback_restores_stock_without_deleting_files(self):
        self.run_install()
        self.run_install('--rollback')
        self.assertEqual(self.state()['enabled'], 'omarchy.lock')
        self.assertTrue((self.target / 'Service.qml').is_file())

    def test_existing_symlink_is_not_followed(self):
        elsewhere = self.root / 'elsewhere'
        elsewhere.mkdir()
        self.target.parent.mkdir(parents=True)
        self.target.symlink_to(elsewhere, target_is_directory=True)
        self.run_install(success=False)
        self.assertTrue(self.target.is_symlink())
        self.assertEqual(list(elsewhere.iterdir()), [])


if __name__ == '__main__':
    unittest.main()
