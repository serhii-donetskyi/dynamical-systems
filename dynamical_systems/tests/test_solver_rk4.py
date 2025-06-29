import pytest
import random
import os
import platform
from dynamical_systems import components, Solver

@pytest.fixture
def factory():
    return components['solver']['rk4']

def test_solver(factory):
    solver = factory.create(h=0.01)
    assert factory.get_argument_types() == [{'name': 'h', 'type': float}]
    assert isinstance(solver, Solver)
    assert solver.get_arguments() == [{'name': 'h', 'value': 0.01}]

def test_rk4_errors(factory):
    with pytest.raises(Exception):
        factory.create(h='0.1')
    with pytest.raises(Exception):
        factory.create(h=0.0)
    with pytest.raises(Exception):
        factory.create(h=1.0)
