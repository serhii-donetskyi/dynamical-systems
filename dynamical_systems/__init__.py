"""
Dynamical Systems Package

A high-level Python interface for numerical analysis of dynamical systems.
"""

from .core import ODEFactory, ODE, SolverFactory, Solver, Job
from .exceptions import *

__version__ = "0.0.1"
__all__ = [
    # Main classes
    'ODEFactory', 'ODE', 'SolverFactory', 'Solver', 'Job',
    
    # Exceptions
    'DynamicalSystemsError', 'FactoryError', 'ArgumentError', 
    'SolverError', 'ODEError'
]

# Convenience functions
def load_ode(libpath: str, **kwargs) -> ODE:
    """Convenience function to load and create an ODE in one step."""
    factory = ODEFactory(libpath)
    return factory.create(**kwargs)

def load_solver(libpath: str, **kwargs) -> Solver:
    """Convenience function to load and create a solver in one step."""
    factory = SolverFactory(libpath)
    return factory.create(**kwargs)
