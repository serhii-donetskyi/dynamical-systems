import pytest
import os
import subprocess
from dynamical_systems import components, generate_module_cmd

@pytest.fixture
def kwargs():
    return {
        'ode': {
            'args': {'n': 2},
            'variables': {
                't': 0.0,
                'x': [0.0, 1.0],
            },
            'parameters': [0.0, 1.0, -1.0, 0.0],
        },
        'solver': {
            'args': {'h': 0.01},
        },
        'job': {
            'args': {'t_end': 1.0, 'file_path': 'portrait.dat'},
        },
    }

@pytest.fixture
def ode(kwargs):
    """Create a test ODE instance."""
    ode_kwargs = kwargs['ode']
    return components['ode']['linear']\
        .create(n=2) \
        .set_t(0.0) \
        .set_x([0.0, 1.0]) \
        .set_p([0.0, 1.0, -1.0, 0.0])

@pytest.fixture
def solver(kwargs):
    """Create a test solver instance."""
    return components['solver']['rk4']\
        .create(h=0.01)

@pytest.fixture
def job():
    return components['job']['portrait']

def test_job(job, ode, solver):
    file_path = 'test_job.txt'
    job.run(ode, solver, t_end=1.0, file_path=file_path)
    assert os.path.exists(file_path)
    os.remove(file_path)

def test_errors(job, ode, solver):
    with pytest.raises(Exception):
        job.run(ode=ode, solver=solver, t_end='1.0', file_path='test_errors.txt')

    with pytest.raises(Exception):
        job.run(ode=ode, solver=solver, t_end=1.0, file_path=123)

def test_module_cmd(ode, solver, job):
    kwargs = {
        'ode': ode,
        'solver': solver,
        't_end': 1.0,
        'file_path': 'test progress.txt',
    }
    process = subprocess.run(
        generate_module_cmd(job, kwargs),
        text=True,
        capture_output=True
    )
    assert os.path.exists(kwargs['file_path'])
    os.remove(kwargs['file_path'])
    assert process.returncode == 0
    lines = [int(line.strip()) for line in process.stdout.split('\n') if line.strip()]
    assert lines == list(range(101))
    