# Dynamical Systems

A high-level Python interface for numerical analysis of dynamical systems with high-performance C implementations.

## Features

- **Fast C implementations** for numerical integration
- **Multiple ODE solvers** (RK4, DOPRI5)
- **Various dynamical systems** (Linear, Spherical Pendulum)
- **Analysis tools** for phase portraits and system analysis
- **Command-line interface** for quick analysis
- **Web interface** for interactive exploration

## Installation

### From Source

```bash
git clone https://github.com/serhii-donetskyi/dynamical-systems.git
cd dynamical-systems
pip install -e .
```

### Development Installation

```bash
git clone https://github.com/serhii-donetskyi/dynamical-systems.git
cd dynamical-systems
pip install -e ".[dev]"
```

## Requirements

- Python 3.9+
- GCC compiler (for building C extensions)

## Quick Start

### Command Line Usage

```bash
# Generate a phase portrait for a linear system
python -m dynamical_systems run \
  --ode linear \
  --ode-args n=2 \
  --ode-variables-t 0.0 \
  --ode-variables-x 0.0 1.0 \
  --ode-parameters 0 1 -1 0 \
  --solver rk4 \
  --solver-args h_max=0.01 \
  --job portrait \
  --job-args t_step=0.1 t_end=10.0 file=portrait.dat

# Or use the script entry point
dynamical-systems run \
  --ode spherical_pendulum \
  --ode-variables-t 0.0 \
  --ode-variables-x 1.0 0.0 0.0 0.0 0.0 \
  --ode-parameters 0.1 0.2 0.3 0.4 \
  --solver dopri5 \
  --solver-args h_max=0.1 eps=1e-6 \
  --job portrait \
  --job-args t_step=0.05 t_end=20.0 file=pendulum.dat
```

### Python API

```python
from dynamical_systems import components

# Get available components
print("Available ODEs:", list(components['ode'].keys()))
print("Available solvers:", list(components['solver'].keys()))
print("Available jobs:", list(components['job'].keys()))

# Create and run a simulation
ode_factory = components['ode']['linear']
solver_factory = components['solver']['rk4']
job_factory = components['job']['portrait']

# Create instances
ode = ode_factory.create(n=2).set_t(0.0).set_x([0.0, 1.0]).set_p([0, 1, -1, 0])
solver = solver_factory.create(h_max=0.01)
job = job_factory.create(t_step=0.1, t_end=10.0, file='portrait.dat')

# Run simulation
job.run(ode, solver)
```

### Web Interface

```bash
# Start the web interface (opens browser automatically)
python -m dynamical_systems ui

# Or specify port and debug mode
python -m dynamical_systems ui --port 8080 --debug

# Default behavior when no arguments (perfect for executables)
python -m dynamical_systems
# or
dynamical-systems
```

The web interface will automatically open at `http://localhost:5001` (or your specified port).

## Available Components

### ODEs

#### `linear`
Linear dynamical systems of the form dx/dt = Ax
- **Parameters**: `n` (integer) - dimension of the system (1-100)
- **State variables**: `n` variables
- **Parameters**: `n×n` matrix elements (row-major order)

#### `spherical_pendulum`
5-dimensional spherical pendulum dynamics
- **State variables**: 5 variables (position and momentum coordinates)
- **Parameters**: 4 parameters (C, D, E, F coefficients)

### Solvers

#### `rk4`
4th-order Runge-Kutta method (fixed step size)
- **Parameters**: `h_max` (float) - maximum step size (0 < h_max < 0.5)

#### `dopri5`
Dormand-Prince 5th-order adaptive method
- **Parameters**: 
  - `h_max` (float) - maximum step size (0 < h_max < 1)
  - `eps` (float) - error tolerance (0 < eps < 1)

### Jobs

#### `portrait`
Generate phase portraits by integrating the system over time
- **Parameters**:
  - `t_step` (float) - output time step
  - `t_end` (float) - end time for integration
  - `file` (string) - output file path (default: "portrait.dat")

## Development

### Building from Source

The package uses C extensions for performance. To build:

```bash
python -m build
```

### Running Tests

```bash
pytest
```

### Project Structure

```
dynamical-systems/
├── src/
│   ├── c/                      # C implementation
│   │   ├── ode/               # ODE implementations
│   │   ├── solver/            # Solver implementations
│   │   └── job/               # Analysis job implementations
│   └── python/                # Python interface
│       └── ui/                # Web interface
├── tests/                     # Test suite
└── dist/                      # Built wheels
```

## License

MIT License - see LICENSE file for details.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Run the test suite
5. Submit a pull request

## Citation

If you use this package in academic work, please cite:

```bibtex
@software{dynamical_systems,
  title = {Dynamical Systems: A Python Package for Numerical Analysis},
  author = {Serhii Donetskyi},
  url = {https://github.com/serhii-donetskyi/dynamical-systems},
  year = {2025}
}
```
