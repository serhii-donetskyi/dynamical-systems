import pytest
import random
from dynamical_systems import Ode


def test_ode(ode_factory):
    ode = ode_factory.create(n=2)
    t = random.random()
    x = [random.random() for _ in range(ode.get_x_size())]
    p = [random.random() for _ in range(ode.get_p_size())]
    ode.set_t(t)
    ode.set_x(x)
    ode.set_p(p)
    assert ode_factory.get_argument_types() == [{"name": "n", "type": int}]
    assert ode_factory.get_name() == "linear"
    assert isinstance(ode, Ode)
    assert ode.get_x_size() == 2
    assert ode.get_p_size() == 4
    assert ode.get_t() == t
    assert ode.get_x() == x
    assert ode.get_p() == p
    assert ode.get_arguments() == [{"name": "n", "value": 2}]


def test_errors(ode_factory):
    with pytest.raises(Exception):
        ode_factory.create(n=-1)
    ode = ode_factory.create(n=2)
    with pytest.raises(Exception):
        ode.set_t("0")
    with pytest.raises(Exception):
        ode.set_x("00")
    with pytest.raises(Exception):
        ode.set_p("0000")
    with pytest.raises(Exception):
        ode.set_x([random.random() for _ in range(ode.get_x_size() - 1)])
    with pytest.raises(Exception):
        ode.set_p([random.random() for _ in range(ode.get_p_size() - 1)])
    with pytest.raises(Exception):
        ode.set_x([random.random() for _ in range(ode.get_x_size() + 1)])
    with pytest.raises(Exception):
        ode.set_p([random.random() for _ in range(ode.get_p_size() + 1)])
