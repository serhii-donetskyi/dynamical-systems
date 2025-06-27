#!/usr/bin/env python3
import os
import subprocess
from setuptools import setup, Extension

current_dir = os.path.dirname(os.path.abspath(__file__))
def walk(dirpath):
    for dirpath, dirnames, filenames in os.walk(dirpath):
        for filename in filenames:
            if filename.endswith(".c"):
                yield os.path.relpath(os.path.join(dirpath, filename), current_dir)

def build_c():
    cmd = [
        "gcc", "-std=c11", "-Wall", "-Wextra", "-Werror", "-pedantic", "-O2",
        "-fPIC", "-I", "src",
    ]
    cflags = subprocess.check_output(["python3-config", "--cflags"], universal_newlines=True).strip()
    ldflags = subprocess.check_output(["python3-config", "--ldflags", "--embed"], universal_newlines=True).strip()

    shared_libs = []
    for cpp in walk(os.path.join(current_dir, "src/ode")):
        shared_libs.append(cpp)
    for cpp in walk(os.path.join(current_dir, "src/solver")):
        shared_libs.append(cpp)
    for cpp in walk(os.path.join(current_dir, "src/job")):
        shared_libs.append(cpp)
    for component in ["ode", "solver", "job"]:
        os.makedirs(os.path.join(current_dir, f"dynamical_systems/{component}"), exist_ok=True)
    try:
        for cpp in shared_libs:
            subprocess.run(
                cmd + [cpp, "-shared", "-o", cpp.replace(".c", ".so").replace("src/", "dynamical_systems/")]
                ,check=True
            )
        # subprocess.run(
        #     ["python3", "setup.py", "build_ext", "--inplace"], check=True
        # )
        # subprocess.run(["./build"], check=True)
    except subprocess.CalledProcessError as e:
        print(f"An error occurred: {e}")
        if e.stdout:
            print(f"Stdout:\\n{e.stdout.decode()}")
        if e.stderr:
            print(f"Stderr:\\n{e.stderr.decode()}")
    finally:
        pass

def build_py():
    # Define the C extension module
    # The name '_dynamical_systems' (with underscore) is a common convention for C modules
    # that are then re-exported by a Python package (__init__.py).
    module = Extension(
        'dynamical_systems._dynamical_systems',
        sources=[
            'src/py_common.c',
            'src/py_ode.c',
            'src/py_solver.c',
            'src/py_job.c',
            'src/python.c',
        ],
        include_dirs=['src'],
        # Uncomment for more warnings during development:
        extra_compile_args=["-std=c11", "-Wall", "-Wextra", "-Werror", "-pedantic", "-O3", "-ffast-math"],
        # extra_link_args=[]
    )
    setup(
        name='dynamical_systems',  # Name of the package for pip
        ext_modules=[module],
        packages=['dynamical_systems'],  # This ensures the dynamical_systems package is included
    )

build_c()
build_py()
