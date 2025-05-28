#!/usr/bin/env python3
import os
import subprocess

current_dir = os.path.dirname(os.path.abspath(__file__))
def walk(dirpath):
    for dirpath, dirnames, filenames in os.walk(dirpath):
        for filename in filenames:
            if filename.endswith(".c"):
                yield os.path.relpath(os.path.join(dirpath, filename), current_dir)

def main():
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
    try:
        for cpp in shared_libs:
            subprocess.run(
                cmd + [cpp, "-shared", "-o", cpp.replace(".c", ".so").replace("src/", "build/")]
                ,check=True
            )
        subprocess.run(
            ["python3", "setup.py", "build_ext", "--inplace"], check=True
        )
        # subprocess.run(["./build"], check=True)
    except subprocess.CalledProcessError as e:
        print(f"An error occurred: {e}")
        if e.stdout:
            print(f"Stdout:\\n{e.stdout.decode()}")
        if e.stderr:
            print(f"Stderr:\\n{e.stderr.decode()}")
    finally:
        pass

if __name__ == "__main__":
    main()

