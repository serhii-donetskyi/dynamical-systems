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

        # Create the package directory structure
        package_dir = os.path.join(self.build_lib, *ext.name.split(".")[:-1])
        os.makedirs(package_dir, exist_ok=True)

        # Get the output filename for the shared library
        lib_fname = f"{ext.name.split('.')[-1]}.so"

        output_path = os.path.join(package_dir, lib_fname)

        # Compile the shared library
        if platform.system() == "Windows":
            self.build_shared_lib_windows(sources[0], output_path, ext.include_dirs)
        else:
            self.build_shared_lib_unix(sources[0], output_path, ext.include_dirs)

        # Create a copy/symlink with the expected Python extension name for the build system
        expected_name = self.get_ext_fullpath(ext.name)
        if os.path.exists(expected_name):
            os.remove(expected_name)

        # Create the directory for the expected file if it doesn't exist
        os.makedirs(os.path.dirname(expected_name), exist_ok=True)

        # Copy the shared library to the expected location
        shutil.copy2(output_path, expected_name)

        # Clear sources to prevent double processing
        ext.sources = []

    def build_shared_lib_windows(self, source, output, include_dirs):
        """Build shared library on Windows using the build_ext compiler"""
        import tempfile
        
        # Create temp directory for object files
        with tempfile.TemporaryDirectory() as temp_dir:
            print(f"Compiling {source}")
            objects = self.compiler.compile(
                sources=[source],
                output_dir=temp_dir,
                include_dirs=include_dirs,
                extra_preargs=compile_args,
            )
            
            print(f"Linking to {output}")
            self.compiler.link_shared_object(
                objects=objects,
                output_filename=output,
                export_symbols=None,
                debug=False,
                extra_preargs=[],
                extra_postargs=[],
                build_temp=temp_dir,
                target_lang=None,
            )

    def build_shared_lib_unix(self, source, output, include_dirs):
        """Build shared library on Unix-like systems using the build_ext compiler"""
        import tempfile
        
        # Create temp directory for object files  
        with tempfile.TemporaryDirectory() as temp_dir:
            print(f"Compiling {source}")
            objects = self.compiler.compile(
                sources=[source],
                output_dir=temp_dir,
                include_dirs=include_dirs,
                extra_preargs=compile_args,
            )
            
            print(f"Linking to {output}")
            self.compiler.link_shared_object(
                objects=objects,
                output_filename=output,
                export_symbols=None,
                debug=False,
                extra_preargs=[],
                extra_postargs=[],
                build_temp=temp_dir,
                target_lang=None,
            )


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
