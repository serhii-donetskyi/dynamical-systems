import pytest
from dynamical_systems import Solver


def test_solver(solver_factory, ode):
    solver = solver_factory.create(h_max=0.01)
    assert solver_factory.get_argument_types() == [{"name": "h_max", "type": float}]
    assert solver_factory.get_name() == "rk4"
    assert isinstance(solver, Solver)
    assert solver.get_arguments() == [{"name": "h_max", "value": 0.01}]
    solver.set_data(ode)


def test_rk4_errors(solver_factory):
    with pytest.raises(Exception):
        solver_factory.create(h_max="0.1")
    with pytest.raises(Exception):
        solver_factory.create(h_max=0.0)
    with pytest.raises(Exception):
        solver_factory.create(h_max=1.0)
