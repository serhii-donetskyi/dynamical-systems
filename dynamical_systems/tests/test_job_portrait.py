import pytest
import os
import subprocess
from dynamical_systems import components, Job, Ode, Solver

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

def test_progress(ode, solver, job):
    t = ode.get_t()
    x = ode.get_x()
    p = ode.get_p()
    ode_args = [f"{d['name']}={d['value']}" for d in ode.get_arguments()]
    solver_args = [f"{d['name']}={d['value']}" for d in solver.get_arguments()]

    process = subprocess.run(
        [
            'python', '-m', 'dynamical_systems',
            '--ode', ode.get_factory().get_name(),
            '--ode-args', *ode_args,
            '--ode-variables-t', str(t),
            '--ode-variables-x', *[str(xi) for xi in x],
            '--ode-parameters', *[str(pi) for pi in p],
            '--solver', solver.get_factory().get_name(),
            '--solver-args', *solver_args,
            '--job', job.get_name(),
            '--job-args', 't_end=1.0', 'file_path=test progress.txt'
        ],
        text=True,
        capture_output=True
    )
    assert os.path.exists('test progress.txt')
    os.remove('test progress.txt')
    assert process.returncode == 0
    lines = [int(line.strip()) for line in process.stdout.split('\n') if line.strip()]
    assert lines == list(range(101))
    