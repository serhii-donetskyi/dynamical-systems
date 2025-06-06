import pytest
import random
import os
import platform
from dynamical_systems.core import ODEFactory, ODE

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
    return ODEFactory(lib_path())

def test_ode(factory):
    kwargs = {'n': 2}
    ode = factory.create(**kwargs)
    t = random.random()
    x = [random.random() for _ in range(ode.x_size)]
    p = [random.random() for _ in range(ode.p_size)]
    ode.t = t
    ode.x = x
    ode.p = p
    assert isinstance(ode, ODE)
    assert ode.x_size == 2
    assert ode.p_size == 4
    assert ode.t == t
    assert ode.x == x
    assert ode.p == p
    assert ode.arguments == kwargs

def test_errors(factory):
    with pytest.raises(Exception):
        factory.create(n=-1)
    ode = factory.create(n=2)
    with pytest.raises(Exception):
        ode.t = 'string'
    with pytest.raises(Exception):
        ode.x = 'string'
    with pytest.raises(Exception):
        ode.p = 'string'
    with pytest.raises(Exception):
        x = [random.random() for _ in range(ode.x_size + 1)]
        ode.x = x
    with pytest.raises(Exception):
        p = [random.random() for _ in range(ode.p_size + 1)]
        ode.p = p
    with pytest.raises(Exception):
        x = [random.random() for _ in range(ode.x_size - 1)]
        ode.x = x
    with pytest.raises(Exception):
        p = [random.random() for _ in range(ode.p_size - 1)]
        ode.p = p
