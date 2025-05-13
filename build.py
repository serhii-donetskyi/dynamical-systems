#!/usr/bin/env python3
import os
import subprocess

current_dir = os.path.dirname(os.path.abspath(__file__))

def main():
    cpps = []
    for dirpath, dirnames, filenames in os.walk(os.path.join(current_dir, "src")):
        for filename in filenames:
            if filename.endswith(".c"):
                cpps.append(os.path.relpath(os.path.join(dirpath, filename), current_dir))
    try:
        subprocess.run(
            ["gcc", "-std=c11", "-Wall", "-Wextra", "-Werror", "-pedantic", "-O2"]
            + ["-I", "src"]
            + cpps + ['main.c']
            + ["-o", "build"]
            ,check=True
        )
        subprocess.run(["./build"], check=True)
    except subprocess.CalledProcessError as e:
        print(f"An error occurred: {e}")
        if e.stdout:
            print(f"Stdout:\\n{e.stdout.decode()}")
        if e.stderr:
            print(f"Stderr:\\n{e.stderr.decode()}")
    finally:
        if os.path.exists("build"):
            os.remove("build")

if __name__ == "__main__":
    main()

