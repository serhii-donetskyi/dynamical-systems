import pytest

from dynamical_systems import components

@pytest.fixture
def ode_factory():
    return components['ode']['linear']

@pytest.fixture
def solver_factory():
    return components['solver']['rk4']

@pytest.fixture
def job_factory():
    return components['job']['portrait']

@pytest.fixture
def ode(ode_factory):
    return ode_factory\
        .create(n=2) \
        .set_t(0.0) \
        .set_x([0.0, 1.0]) \
        .set_p([0.0, 1.0, -1.0, 0.0])

@pytest.fixture
def solver(solver_factory):
    return solver_factory.create(h_max=0.01)

@pytest.fixture
def job(job_factory):
    return job_factory.create(t_step=0.5, t_end=1.0, file='portrait.txt')
