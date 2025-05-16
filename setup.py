from setuptools import setup, Extension

# Define the C extension module
# The name '_dynamical_systems' (with underscore) is a common convention for C modules
# that are then re-exported by a Python package (__init__.py).
dynamical_systems_extension = Extension(
    'dynamical_systems',  # Name of the .so file will be _dynamical_systems.so
    sources=[
        'src/core/ode.c',
        'src/core/solver.c',
        'src/py_ode.c',
        'src/py_solver.c',
        'src/py_job.c',
        'src/py_utils.c',
        'src/python.c',
    ],
    include_dirs=[
        'src',
        # 'src/c_core'
    ],
    # Uncomment for more warnings during development:
    extra_compile_args=["-std=c11", "-Wall", "-Wextra", "-Werror", "-pedantic", "-O2"],
    # extra_link_args=[]
)

setup(
    name='dynamical_systems',  # Name of the package for pip
    version='0.1.0',
    description='Python interface for dynamical systems simulation in C',
    long_description='A module for simulating dynamical systems, with core logic in C.',
    ext_modules=[dynamical_systems_extension],
    packages=['dynamical_systems'],  # Tells setuptools to include the dynamical_systems package
    # You might need to specify package_dir if your layout is different,
    # but for `dynamical_systems` package in root, this should be fine.
    # Example: package_dir={'dynamical_systems': 'dynamical_systems'},
    author='Your Name',
    author_email='your.email@example.com',
    # license='MIT', # Choose an appropriate license
) 