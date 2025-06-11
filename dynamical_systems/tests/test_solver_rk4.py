import pytest
import random
import os
import platform
from dynamical_systems import SolverFactory, Solver

def lib_path():
    """Get the correct library path based on the platform."""
    # Get the base path relative to the test file
    base_path = os.path.join("build", "solver", "rk4")
    
    # Add the correct extension based on platform
    if platform.system() == "Windows":
        return f"{base_path}.dll"
    else:
        return f"{base_path}.so"

@pytest.fixture
def factory():
    return SolverFactory(lib_path())

def test_solver(factory):
    kwargs = {'h': 0.01}
    solver = factory.create(**kwargs)
    assert isinstance(solver, Solver)
    assert solver.get_arguments() == kwargs

def test_rk4_errors(factory):
    with pytest.raises(Exception):
        factory.create(h='string')
    with pytest.raises(Exception):
        factory.create(h=0.0)
    with pytest.raises(Exception):
        factory.create(h=1.0)
