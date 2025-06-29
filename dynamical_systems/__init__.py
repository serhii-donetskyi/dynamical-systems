"""
Dynamical Systems Package

A high-level Python interface for numerical analysis of dynamical systems.
"""

import os

from ._dynamical_systems import OdeFactory, SolverFactory, Job, Ode, Solver

factories = {
    "ode": OdeFactory,
    "solver": SolverFactory,
    "job": Job,
}

components = {
    "ode": {},
    "solver": {},
    "job": {},
}

current_dir = os.path.dirname(__file__)
for component in ["ode", "solver", "job"]:
    component_dir = os.path.join(current_dir, component)
    for fname in os.listdir(component_dir):
        if fname.endswith(".so"):
            name = fname.replace(".so", "")
            component_path = os.path.join(component_dir, fname)
            components[component][name] = factories[component](component_path)

__version__ = "0.0.1"
__all__ = [
    'OdeFactory', 'SolverFactory', 
    'Ode', 'Solver', 'Job',
    'components',
]
