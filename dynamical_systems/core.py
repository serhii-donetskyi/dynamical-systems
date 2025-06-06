import os
from typing import Dict, Any, Optional, List
from ._dynamical_systems import OdeFactory, SolverFactory as _SolverFactory, Job as _Job


class ODEFactory:
    """High-level wrapper for ODE factory."""
    
    def __init__(self, libpath: str):
        """Initialize ODE factory.
        
        Args:
            libpath: Path to the ODE shared library
            
        Raises:
            FactoryError: If library cannot be loaded
        """
        if not os.path.exists(libpath):
            raise ValueError(f"Library not found: {libpath}")
            
        self._factory = OdeFactory(libpath=libpath)
    
    @property
    def argument_types(self) -> Dict[str, str]:
        """Get required argument types for this ODE."""
        return self._factory.get_argument_types()
    
    def create(self, **kwargs) -> 'ODE':
        """Create an ODE instance with given parameters.
        
        Args:
            **kwargs: Arguments required by the ODE
            
        Returns:
            ODE instance
            
        Raises:
            ArgumentError: If arguments are invalid
        """
        # Validate arguments
        self._validate_arguments(kwargs)
        
        ode_obj = self._factory.create_ode(**kwargs)
        return ODE(ode_obj)
    
    def _validate_arguments(self, kwargs: Dict[str, Any]):
        """Validate arguments against expected types."""
        expected = self.argument_types
        
        # Check for missing arguments
        missing = set(expected.keys()) - set(kwargs.keys())
        if missing:
            raise ValueError(f"Missing required arguments: {missing}")
        
        # Check for extra arguments
        extra = set(kwargs.keys()) - set(expected.keys())
        if extra:
            raise ValueError(f"Unexpected arguments: {extra}")
        
        for name, value in kwargs.items():
            expected_type = expected[name]
            if not isinstance(value, expected_type):
                raise ValueError(f"Argument '{name}' should be {expected_type}, got {type(value).__name__}")
        

class ODE:
    """High-level wrapper for ODE objects."""
    
    def __init__(self, ode_obj):
        """Initialize with low-level ODE object."""
        self._ode = ode_obj
    
    @property
    def name(self) -> str:
        """Get ODE name."""
        return self._ode.get_name()
    
    @property
    def arguments(self) -> Dict[str, Any]:
        """Get ODE arguments."""
        return self._ode.get_arguments()
    
    @property
    def x_size(self) -> int:
        """Get state vector size."""
        return self._ode.get_x_size()
    
    @property
    def p_size(self) -> int:
        """Get parameter vector size."""
        return self._ode.get_p_size()
    
    @property
    def t(self) -> float:
        """Get current time."""
        return self._ode.get_t()
    
    @t.setter
    def t(self, value: float):
        """Set current time."""
        self._ode.set_t(value=float(value))
    
    def set_x(self, index: int, value: float):
        """Set state vector component."""
        self._ode.set_x(index=index, value=float(value))
    
    @property
    def x(self) -> List[float]:
        """Get state vector."""
        return self._ode.get_x()

    @x.setter
    def x(self, values: List[float]):
        """Set entire state vector."""
        if len(values) != self.x_size:
            raise ValueError(f"State vector must have {self.x_size} elements, got {len(values)}")
        
        for i, value in enumerate(values):
            self.set_x(i, value)
    
    def set_p(self, index: int, value: float):
        """Set parameter vector component."""
        self._ode.set_p(index=index, value=float(value))
    
    @property
    def p(self) -> List[float]:
        """Get parameter vector."""
        return self._ode.get_p()

    @p.setter
    def p(self, values: List[float]):
        """Set entire parameter vector."""
        if len(values) != self.p_size:
            raise ValueError(f"Parameter vector must have {self.p_size} elements, got {len(values)}")
        for i, value in enumerate(values):
            self.set_p(i, value)


class SolverFactory:
    """High-level wrapper for Solver factory."""
    
    def __init__(self, libpath: str):
        if not os.path.exists(libpath):
            raise ValueError(f"Library not found: {libpath}")
        self._factory = _SolverFactory(libpath=libpath)
    
    @property
    def argument_types(self) -> Dict[str, str]:
        return self._factory.get_argument_types()
    
    def create(self, **kwargs) -> 'Solver':
        """Create a solver instance."""
        solver_obj = self._factory.create_solver(**kwargs)
        return Solver(solver_obj)


class Solver:
    """High-level wrapper for Solver objects."""
    
    def __init__(self, solver_obj):
        self._solver = solver_obj
    
    @property
    def name(self) -> str:
        return self._solver.get_name()
    
    @property
    def arguments(self) -> Dict[str, Any]:
        return self._solver.get_arguments()


class Job:
    """High-level wrapper for Job objects."""
    
    def __init__(self, libpath: str):
        if not os.path.exists(libpath):
            raise ValueError(f"Library not found: {libpath}")
        self._job = _Job(libpath=libpath)
    
    @property
    def name(self) -> str:
        return self._job.get_name()
    
    @property
    def argument_types(self) -> Dict[str, str]:
        return self._job.get_argument_types()
    
    def run(self, ode: ODE, solver: Solver, **kwargs):
        """Run the job with given ODE and solver."""
        return self._job.run(ode=ode._ode, solver=solver._solver, **kwargs)