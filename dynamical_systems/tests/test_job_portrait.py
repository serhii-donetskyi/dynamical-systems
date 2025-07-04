import pytest
import os
import subprocess
from dynamical_systems import components, Job, generate_module_cmd

@pytest.fixture
def ode():
    """Create a test ODE instance."""
    return components['ode']['linear']\
        .create(n=2) \
        .set_t(0.0) \
        .set_x([0.0, 1.0]) \
        .set_p([0.0, 1.0, -1.0, 0.0])

@pytest.fixture
def solver():
    """Create a test solver instance."""
    return components['solver']['rk4'].create(h_max=0.01)

@pytest.fixture
def factory():
    return components['job']['portrait']

def test_job(factory, ode, solver):
    file = 'portrait.txt'
    job = factory.create(t_step=0.5, t_end=1.0, file=file)
    assert factory.get_argument_types() == [{'name': 't_step', 'type': float}, {'name': 't_end', 'type': float}, {'name': 'file', 'type': str}]
    assert isinstance(job, Job)
    assert job.get_arguments() == [{'name': 't_step', 'value': 0.5}, {'name': 't_end', 'value': 1.0}, {'name': 'file', 'value': file}]
    job.run(ode, solver)
    assert os.path.exists(file)
    os.remove(file)

def test_errors(factory):
    with pytest.raises(Exception):
        factory.create(t_step='0.5', t_end=1.0, file='test_errors.txt')
    with pytest.raises(Exception):
        factory.create(t_step=0.5, t_end='1.0', file='test_errors.txt')
    with pytest.raises(Exception):
        factory.create(t_step=0.5, t_end=1.0, file=123)

def test_module_cmd(factory, ode, solver):
    file = 'test_progress.txt'
    job = factory.create(t_step=0.5, t_end=1.0, file=file)
    process = subprocess.run(
        generate_module_cmd(ode, solver, job),
        text=True,
        capture_output=True
    )
    assert os.path.exists(file)
    os.remove(file)
    assert process.returncode == 0
    lines = [int(line.strip()) for line in process.stdout.split('\n') if line.strip()]
    assert lines == list(range(101))
    