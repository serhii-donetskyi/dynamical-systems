"""
Dynamical Systems Package

A high-level Python interface for numerical analysis of dynamical systems.
"""

from ._dynamical_systems import OdeFactory, SolverFactory, Job, Ode, Solver

__version__ = "0.0.1"
__all__ = [
    # Main classes
    'OdeFactory', 'Ode', 'SolverFactory', 'Solver', 'Job',
]
