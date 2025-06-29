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

def generate_module_cmd(job, kwargs):
    ode_args = [
        f"{arg['name']}={arg['value']}"
        for arg in kwargs['ode'].get_arguments()
    ]
    solver_args = [
        f"{arg['name']}={arg['value']}"
        for arg in kwargs['solver'].get_arguments()
    ]
    job_args = [
        f"{name}={value}"
        for name, value in kwargs.items()
        if name not in ['ode', 'solver']
    ]
    return [
        "python", "-m", "dynamical_systems",
        "--ode", kwargs['ode'].get_factory().get_name(),
        "--ode-args", *ode_args,
        "--ode-variables-t", str(kwargs['ode'].get_t()),
        "--ode-variables-x", *[str(x) for x in kwargs['ode'].get_x()],
        "--ode-parameters", *[str(p) for p in kwargs['ode'].get_p()],
        "--solver", kwargs['solver'].get_factory().get_name(),
        "--solver-args", *solver_args,
        "--job", job.get_name(),
        "--job-args", *job_args,
    ]

__version__ = "0.0.1"
__all__ = [
    'OdeFactory', 'SolverFactory', 
    'Ode', 'Solver', 'Job',
    'components',
]
