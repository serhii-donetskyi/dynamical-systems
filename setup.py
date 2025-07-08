#!/usr/bin/env python3
import os
import platform
import shutil
from setuptools import setup, Extension
from setuptools.command.build_ext import build_ext as _build_ext

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


class BuildExtWithSharedLibs(_build_ext):
    def build_extension(self, ext):
        if ext.name == "dynamical_systems._dynamical_systems":
            super().build_extension(ext)
        else:
            # Build shared libraries for component files
            self.build_shared_lib(ext)

    def build_shared_lib(self, ext):
        """Build a shared library instead of a Python extension module"""
        sources = ext.sources
        if not sources:
            return

        expected_name = self.get_ext_fullpath(ext.name)
        # Create the directory for the expected file if it doesn't exist
        os.makedirs(os.path.dirname(expected_name), exist_ok=True)

        # Step 1: Compile sources to object files
        print(f"Compiling {sources} for {ext.name}")
        objects = self.compiler.compile(
            sources=sources,
            output_dir=self.build_lib,
            include_dirs=ext.include_dirs,
            extra_preargs=compile_args,
        )

        # Step 2: Link object files into shared library
        print(f"Linking to {expected_name}")
        if platform.system() == "Windows":
            # For Windows, use /LD flag to create DLL
            self.compiler.link_shared_object(
                objects=objects,
                output_filename=expected_name,
                export_symbols=None,
                debug=False,
                extra_preargs=[],
                extra_postargs=[],
                build_temp=self.build_lib,
                target_lang=None,
            )
        else:
            # For Unix-like systems, use -shared flag
            self.compiler.link_shared_object(
                objects=objects,
                output_filename=expected_name,
                export_symbols=None,
                debug=False,
                extra_preargs=[],
                extra_postargs=[],
                build_temp=self.build_lib,
                target_lang=None,
            )
        
        ext.sources = []

# Create extensions for component files (to be built as shared libraries)
c_extensions = []
for component in ["ode", "solver", "job"]:
    for c_file in walk(os.path.join(src_c_dir, component)):
        name = os.path.basename(c_file).replace(".c", "")
        c_extensions.append(
            Extension(
                f"dynamical_systems.{component}.{name}",
                sources=[c_file],
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
    ext_modules=[py_extension] + c_extensions,
    cmdclass={"build_ext": BuildExtWithSharedLibs},
)
