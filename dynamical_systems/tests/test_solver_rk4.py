import pytest
import random
import os
import platform
from dynamical_systems import components, Solver

@pytest.fixture
def ode():
    return components['ode']['linear'].create(n=2)

@pytest.fixture
def factory():
    return components['solver']['rk4']

def test_solver(factory, ode):
    solver = factory.create(h_max=0.01)
    assert factory.get_argument_types() == [{'name': 'h_max', 'type': float}]
    assert isinstance(solver, Solver)
    assert solver.get_arguments() == [{'name': 'h_max', 'value': 0.01}]
    solver.set_data(ode)

def test_rk4_errors(factory):
    with pytest.raises(Exception):
        factory.create(h_max='0.1')
    with pytest.raises(Exception):
        factory.create(h_max=0.0)
    with pytest.raises(Exception):
        factory.create(h_max=1.0)
