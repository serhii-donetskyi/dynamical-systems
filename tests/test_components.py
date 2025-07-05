import pytest
from dynamical_systems import components


def test_components():
    for component in components:
        for name, factory in components[component].items():
            assert factory.get_name() == name
            for arg in factory.get_argument_types():
                assert "name" in arg
                assert "type" in arg
                assert isinstance(arg["name"], str)
                assert arg["type"] in [int, float, str]
                assert hasattr(factory, "create") or hasattr(factory, "run")
