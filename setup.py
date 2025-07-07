#!/usr/bin/env python3
import os
import platform
from setuptools import setup, Extension

current_dir = os.path.dirname(os.path.abspath(__file__))
src_c_dir = os.path.join("src", "c")


# Platform-specific compiler arguments
def get_compile_args():
    if platform.system() == "Windows":
        # MSVC compiler flags
        return [
            "/O2",  # Optimize for speed (equivalent to -O3)
            "/W3",  # Warning level 3
            "/WX",  # Treat warnings as errors
            "/std:c11",  # C11 standard (VS 2019+)
            "/fp:fast",  # Fast floating point model (equivalent to -ffast-math)
        ]
    else:
        # GCC/Clang compiler flags for Unix-like systems
        return [
            "-std=c11",
            "-Wall",
            "-Wextra",
            "-Werror",
            "-pedantic",
            "-O3",
            "-ffast-math",
            "-fPIC",  # Position Independent Code
        ]


compile_args = get_compile_args()


def walk(dirpath):
    for dirpath, dirnames, filenames in os.walk(dirpath):
        for filename in filenames:
            if filename.endswith(".c"):
                yield os.path.relpath(os.path.join(dirpath, filename), current_dir)


c_extensions = []
for component in ["ode", "solver", "job"]:
    for c_file in walk(os.path.join(src_c_dir, component)):
        name = os.path.basename(c_file).replace(".c", "")
        c_extensions.append(
            Extension(
                f"dynamical_systems.{component}.{name}",
                sources=[c_file],  # Each extension gets its own source file
                include_dirs=[src_c_dir],
                extra_compile_args=compile_args,
            )
        )

# Define the main C extension module
py_extension = Extension(
    "dynamical_systems._dynamical_systems",
    sources=[
        os.path.join(src_c_dir, "py_common.c"),
        os.path.join(src_c_dir, "py_ode.c"),
        os.path.join(src_c_dir, "py_solver.c"),
        os.path.join(src_c_dir, "py_job.c"),
        os.path.join(src_c_dir, "python.c"),
    ],
    include_dirs=[src_c_dir],
    extra_compile_args=compile_args,
)

# Use setup() for extension building only
# Most configuration is now in pyproject.toml
setup(
    name="dynamical_systems",
    # Point to the source directory for the Python package
    package_dir={"dynamical_systems": "src/python"},
    ext_modules=[py_extension] + c_extensions,
)
