#!/usr/bin/env python3
import os
import platform
import shutil
from setuptools import setup, Extension
from setuptools.command.build_ext import build_ext as _build_ext
import subprocess

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

        # Use the same compiler that build_ext uses
        compiler_cmd = self.compiler.compiler_so[0]  # Get the base compiler command

        # Create temp directory for object files
        with tempfile.TemporaryDirectory() as temp_dir:
            obj_file = os.path.join(temp_dir, "temp.obj")

            # Compile to object file using the build_ext compiler
            compile_cmd = [compiler_cmd, "/c", "/Fo" + obj_file]

            # Add include directories
            for include_dir in include_dirs:
                compile_cmd.append(f"/I{include_dir}")

            # Add our compile args
            compile_cmd.extend(compile_args)
            compile_cmd.append(source)

            print(f"Building shared library (compile): {' '.join(compile_cmd)}")
            subprocess.run(compile_cmd, check=True)

            # Link to DLL - for MSVC, we can try to find the linker
            # or use the compiler's linker capability
            if hasattr(self.compiler, "linker_so"):
                linker_cmd = [
                    self.compiler.linker_so[0],
                    "/DLL",
                    "/OUT:" + output,
                    obj_file,
                ]
            else:
                # Fallback to link.exe if linker_so is not available
                linker_cmd = ["link.exe", "/DLL", "/OUT:" + output, obj_file]

            print(f"Building shared library (link): {' '.join(linker_cmd)}")
            subprocess.run(linker_cmd, check=True)

    def build_shared_lib_unix(self, source, output, include_dirs):
        """Build shared library on Unix-like systems using the build_ext compiler"""
        # Use the same compiler that build_ext uses
        compiler_cmd = self.compiler.compiler_so[0]  # Get the base compiler command

        cmd = [compiler_cmd, "-shared", "-o", output]

        for include_dir in include_dirs:
            cmd.append(f"-I{include_dir}")

        cmd.extend(compile_args)
        cmd.append(source)

        print(f"Building shared library: {' '.join(cmd)}")
        subprocess.run(cmd, check=True)


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
