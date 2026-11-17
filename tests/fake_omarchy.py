#!/usr/bin/env python3
"""Local IPC/manager double; filesystem writes remain in the real installer."""
import json
import os
from pathlib import Path
import sys

path = Path(os.environ['ETHEREAL_TEST_STATE'])
state = json.loads(path.read_text())
args = sys.argv[1:]
state['calls'].append([Path(sys.argv[0]).name, *args])
path.write_text(json.dumps(state))
if args == ['lock', 'status']:
    if state.get('ipcFail'):
        sys.exit(1)
    print(json.dumps(state['status']))
elif args[:2] == ['plugin', 'validate']:
    assert json.loads((Path(args[2]) / 'manifest.json').read_text())['id'] == 'ethereal.lock'
elif args == ['plugin', 'list', '--json']:
    rows = [{'id': 'omarchy.lock', 'enabled': state['enabled'] == 'omarchy.lock'}]
    if (Path.home() / '.config/omarchy/plugins/ethereal.lock').exists():
        rows.append({'id': 'ethereal.lock', 'enabled': state['enabled'] == 'ethereal.lock'})
    print(json.dumps(rows))
elif args[:2] == ['plugin', 'enable']:
    if args[2] == 'ethereal.lock' and state.get('failEnable'):
        sys.exit(1)
    state['enabled'] = args[2]
    if state.get('failReady'):
        state['status']['passwordPam'] = args[2] == 'omarchy.lock'
    path.write_text(json.dumps(state))
elif args[:2] == ['plugin', 'disable']:
    if state['enabled'] == args[2]:
        state['enabled'] = 'omarchy.lock'
        path.write_text(json.dumps(state))
elif args in (['shell', 'rescanPlugins'], ['shell', 'reloadPlugins']):
    pass
else:
    raise RuntimeError(f'Unexpected test command: {args}')
