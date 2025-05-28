from setuptools import setup, Extension

# Define the C extension module
# The name '_dynamical_systems' (with underscore) is a common convention for C modules
# that are then re-exported by a Python package (__init__.py).
module = Extension(
    'dynamical_systems',
    sources=['src/python.c', 'src/py_ode.c'],
    include_dirs=['src'],
    # Uncomment for more warnings during development:
    extra_compile_args=["-std=c11", "-Wall", "-Wextra", "-Werror", "-pedantic", "-O3", "-ffast-math"],
    # extra_link_args=[]
)

setup(
    name='dynamical_systems',  # Name of the package for pip
    ext_modules=[module],
) 