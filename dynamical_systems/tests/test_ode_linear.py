import pytest
import random
import os
import platform
from dynamical_systems import OdeFactory, Ode

def lib_path():
    """Get the correct library path based on the platform."""
    # Get the base path relative to the test file
    base_path = os.path.join("build", "ode", "linear")
    
    # Add the correct extension based on platform
    if platform.system() == "Windows":
        return f"{base_path}.dll"
    else:
        return f"{base_path}.so"

@pytest.fixture
def factory():
    return OdeFactory(lib_path())

def test_ode(factory):
    kwargs = {'n': 2}
    ode = factory.create(**kwargs)
    t = random.random()
    x = [random.random() for _ in range(ode.get_x_size())]
    p = [random.random() for _ in range(ode.get_p_size())]
    ode.set_t(t)
    for i in range(len(x)):
        ode.set_x(i, x[i])
    for i in range(len(p)):
        ode.set_p(i, p[i])
    assert isinstance(ode, Ode)
    assert ode.get_x_size() == 2
    assert ode.get_p_size() == 4
    assert ode.get_t() == t
    assert ode.get_x() == x
    assert ode.get_p() == p
    assert ode.get_arguments() == kwargs

def test_errors(factory):
    with pytest.raises(Exception):
        factory.create(n=-1)
    ode = factory.create(n=2)
    with pytest.raises(Exception):
        ode.set_t('string')
    with pytest.raises(Exception):
        ode.set_x(0, 'string')
    with pytest.raises(Exception):
        ode.set_p(0, 'string')
    with pytest.raises(Exception):
        for i in range(ode.get_x_size() + 1):
            ode.set_x(i, random.random())
    with pytest.raises(Exception):
        for i in range(ode.get_p_size() + 1):
            ode.set_p(i, random.random())
