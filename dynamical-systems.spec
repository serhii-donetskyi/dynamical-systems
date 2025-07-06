# -*- mode: python ; coding: utf-8 -*-

import os
import sys
from pathlib import Path

block_cipher = None

# Get the current directory
current_dir = os.getcwd()

# Collect all .so files (C extensions)
binaries = []
for root, dirs, files in os.walk(os.path.join(current_dir, 'dynamical_systems')):
    for file in files:
        if file.endswith('.so'):
            full_path = os.path.join(root, file)
            # Create the destination path relative to dynamical_systems
            rel_path = os.path.relpath(full_path, current_dir)
            binaries.append((full_path, os.path.dirname(rel_path)))

# Collect static files for the UI
datas = []
ui_static_path = os.path.join(current_dir, 'dynamical_systems', 'ui', 'static')
ui_templates_path = os.path.join(current_dir, 'dynamical_systems', 'ui', 'templates')

if os.path.exists(ui_static_path):
    for root, dirs, files in os.walk(ui_static_path):
        for file in files:
            full_path = os.path.join(root, file)
            rel_path = os.path.relpath(full_path, current_dir)
            datas.append((full_path, os.path.dirname(rel_path)))

if os.path.exists(ui_templates_path):
    for root, dirs, files in os.walk(ui_templates_path):
        for file in files:
            full_path = os.path.join(root, file)
            rel_path = os.path.relpath(full_path, current_dir)
            datas.append((full_path, os.path.dirname(rel_path)))

# Hidden imports for Flask and other dependencies
hiddenimports = [
    'flask',
    'flask_cors',
    'jinja2',
    'markupsafe',
    'werkzeug',
    'click',
    'itsdangerous',
    'blinker',
    'dynamical_systems',
    'dynamical_systems.ui',
    'dynamical_systems._dynamical_systems',
]

a = Analysis(
    ['dynamical_systems/__main__.py'],
    pathex=[current_dir],
    binaries=binaries,
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.zipfiles,
    a.datas,
    [],
    name='dynamical-systems',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
) 