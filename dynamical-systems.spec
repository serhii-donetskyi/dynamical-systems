# -*- mode: python ; coding: utf-8 -*-

import os
import sys
from pathlib import Path

block_cipher = None

# Get the current directory
current_dir = os.getcwd()

# Find the dynamical_systems module directory automatically
try:
    import dynamical_systems
    module_dir = os.path.dirname(dynamical_systems.__file__)
    print(f"Found dynamical_systems module at: {module_dir}")
except ImportError:
    raise RuntimeError("dynamical_systems module not found. Please install it first with 'pip install -e .'")

# Add module directory to pathex
pathex_dirs = [current_dir, module_dir]

# Collect all binaries and data files from the module directory
binaries = []
datas = []

# Walk through the entire module directory to collect everything
for root, dirs, files in os.walk(module_dir):
    for file in files:
        full_path = os.path.join(root, file)
        rel_path = os.path.relpath(full_path, module_dir)
        dest_path = os.path.join('dynamical_systems', rel_path)

        if file.endswith(('.so', '.pyd', '.dll')):
            # Binary files (C extensions)
            binaries.append((full_path, os.path.dirname(dest_path)))
        elif not file.endswith(('.pyc', '.pyo')) and not file.startswith('.'):
            # Data files (Python files, templates, static files, etc.)
            # Skip compiled Python files and hidden files
            datas.append((full_path, os.path.dirname(dest_path)))

print(f"Collected {len(binaries)} binary files:")
for binary in binaries:
    print(f"  {binary[0]} -> {binary[1]}")

print(f"Collected {len(datas)} data files:")
for data in datas[:10]:  # Show first 10 to avoid spam
    print(f"  {data[0]} -> {data[1]}")
if len(datas) > 10:
    print(f"  ... and {len(datas) - 10} more files")

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

# Use the module's __main__.py
main_script = os.path.join(module_dir, '__main__.py')
if not os.path.exists(main_script):
    raise RuntimeError(f"Main script not found at {main_script}")

a = Analysis(
    [main_script],
    pathex=pathex_dirs,
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
