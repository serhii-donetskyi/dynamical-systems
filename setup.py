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


def build_shared_libraries():
    """Build individual C components as shared libraries"""
    shared_libs = []
    for cpp in walk(os.path.join(current_dir, "src/ode")):
        shared_libs.append(cpp)
    for cpp in walk(os.path.join(current_dir, "src/solver")):
        shared_libs.append(cpp)
    for cpp in walk(os.path.join(current_dir, "src/job")):
        shared_libs.append(cpp)

    # Create component directories
    for component in ["ode", "solver", "job"]:
        os.makedirs(
            os.path.join(current_dir, f"dynamical_systems/{component}"), exist_ok=True
        )

    # Build shared libraries
    cmd = [
        "gcc",
        "-std=c11",
        "-Wall",
        "-Wextra",
        "-Werror",
        "-pedantic",
        "-O3",
        "-ffast-math",
        "-fPIC",
        "-I",
        "src",
    ]

    try:
        for cpp in shared_libs:
            output_path = cpp.replace(".c", ".so").replace("src/", "dynamical_systems/")
            subprocess.run(cmd + [cpp, "-shared", "-o", output_path], check=True)
            print(f"Built {cpp} -> {output_path}")
    except subprocess.CalledProcessError as e:
        print(f"An error occurred: {e}")
        if e.stdout:
            print(f"Stdout:\\n{e.stdout.decode()}")
        if e.stderr:
            print(f"Stderr:\\n{e.stderr.decode()}")


# Build shared libraries before setup
build_shared_libraries()

# Define the main C extension module
extension = Extension(
    "dynamical_systems._dynamical_systems",
    sources=[
        "src/py_common.c",
        "src/py_ode.c",
        "src/py_solver.c",
        "src/py_job.c",
        "src/python.c",
    ],
    include_dirs=["src"],
    extra_compile_args=[
        "-std=c11",
        "-Wall",
        "-Wextra",
        "-Werror",
        "-pedantic",
        "-O3",
        "-ffast-math",
    ],
)

# Use setup() for extension building only
# Most configuration is now in pyproject.toml
setup(
    name="dynamical_systems",
    ext_modules=[extension],
)
