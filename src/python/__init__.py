"""
Dynamical Systems Package

A high-level Python interface for numerical analysis of dynamical systems.
"""

import os
import sys

from ._dynamical_systems import OdeFactory, SolverFactory, JobFactory, Job, Ode, Solver


factories = {
    "ode": OdeFactory,
    "solver": SolverFactory,
    "job": JobFactory,
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
            name, _ = fname.split(".", 1)
            component_path = os.path.join(component_dir, fname)
            components[component][name] = factories[component](component_path)


def generate_module_cmd(ode, solver, job):
    ode_args = [f"{arg['name']}={arg['value']}" for arg in ode.get_arguments()]
    solver_args = [f"{arg['name']}={arg['value']}" for arg in solver.get_arguments()]
    job_args = [f"{arg['name']}={arg['value']}" for arg in job.get_arguments()]
    return [
        sys.executable,
        "-m",
        "dynamical_systems",
        "run",
        "--ode",
        ode.get_factory().get_name(),
        "--ode-args",
        *ode_args,
        "--ode-variables-t",
        str(ode.get_t()),
        "--ode-variables-x",
        *[str(x) for x in ode.get_x()],
        "--ode-parameters",
        *[str(p) for p in ode.get_p()],
        "--solver",
        solver.get_factory().get_name(),
        "--solver-args",
        *solver_args,
        "--job",
        job.get_factory().get_name(),
        "--job-args",
        *job_args,
    ]


__all__ = [
    "OdeFactory",
    "SolverFactory",
    "JobFactory",
    "Ode",
    "Solver",
    "Job",
    "components",
    "generate_module_cmd",
]

try:
    from ._version import __version__
except ImportError:
    __version__ = "0.0.1"
