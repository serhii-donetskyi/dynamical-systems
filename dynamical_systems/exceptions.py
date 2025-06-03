class DynamicalSystemsError(Exception):
    """Base exception for dynamical systems package."""
    pass

class FactoryError(DynamicalSystemsError):
    """Error in factory operations."""
    pass

class ArgumentError(DynamicalSystemsError):
    """Error in argument validation."""
    pass

class SolverError(DynamicalSystemsError):
    """Error in solver operations.""" 
    pass

class ODEError(DynamicalSystemsError):
    """Error in ODE operations."""
    pass