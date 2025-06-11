import pytest
import random
import os
import platform
from dynamical_systems import OdeFactory, Ode, SolverFactory, Solver, Job

def ode_lib_path():
    """Get the correct ODE library path based on the platform."""
    # Get the base path relative to the test file
    base_path = os.path.join("build", "ode", "linear")
    
    # Add the correct extension based on platform
    if platform.system() == "Windows":
        return f"{base_path}.dll"
    else:
        return f"{base_path}.so"

def solver_lib_path():
    """Get the correct solver library path based on the platform."""
    # Get the base path relative to the test file
    base_path = os.path.join("build", "solver", "rk4")
    
    # Add the correct extension based on platform
    if platform.system() == "Windows":
        return f"{base_path}.dll"
    else:
        return f"{base_path}.so"

def job_lib_path():
    """Get the correct job library path based on the platform."""
    # Get the base path relative to the test file
    base_path = os.path.join("build", "job", "portrait")
    
    # Add the correct extension based on platform
    if platform.system() == "Windows":
        return f"{base_path}.dll"
    else:
        return f"{base_path}.so"

@pytest.fixture
def ode_factory():
    return OdeFactory(ode_lib_path())

@pytest.fixture
def solver_factory():
    return SolverFactory(solver_lib_path())

@pytest.fixture
def job():
    return Job(job_lib_path())

@pytest.fixture
def ode(ode_factory):
    """Create a test ODE instance."""
    kwargs = {'n': 2}
    ode = ode_factory.create(**kwargs)
    t = 0.0
    x = [0.0, -1.0]
    p = [0.0, 1.0, -1.0, 0.0]
    ode.set_t(t)
    for i in range(len(x)):
        ode.set_x(i, x[i])
    for i in range(len(p)):
        ode.set_p(i, p[i])
    return ode

@pytest.fixture
def solver(solver_factory):
    """Create a test solver instance."""
    kwargs = {'h': 0.01}
    return solver_factory.create(**kwargs)

def test_job(job, ode, solver):
    kwargs = {
        'ode': ode,
        'solver': solver,
        't_end': 1.0,
        'max_steps': 1000000,
        'file_path': 'portrait.dat',
    }
    job.run(**kwargs)
    assert os.path.exists('portrait.dat')
    os.remove('portrait.dat')

def test_errors(job, ode, solver):
    with pytest.raises(Exception):
        job.run(ode=ode, solver=solver, t_end='string', max_steps=1000000, file_path='portrait.dat')
    
    with pytest.raises(Exception):
        job.run(ode=ode, solver=solver, t_end=1.0, max_steps='string', file_path='portrait.dat')
    
    with pytest.raises(Exception):
        job.run(ode=ode, solver=solver, t_end=1.0, max_steps=1000000, file_path=123)
