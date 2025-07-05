# Dynamical Systems

A high-level Python interface for numerical analysis of dynamical systems with high-performance C implementations.

## Features

- **Fast C implementations** for numerical integration
- **Multiple ODE solvers** (RK4, DOPRI5, etc.)
- **Various dynamical systems** (Linear, Lorenz, Van der Pol, etc.)
- **Analysis tools** for phase portraits and system analysis
- **Command-line interface** for quick analysis
- **Web interface** for interactive exploration

## Installation

### From PyPI (Recommended)

```bash
pip install dynamical-systems
```

### From Source

```bash
git clone https://github.com/yourusername/dynamical-systems.git
cd dynamical-systems
pip install -e .
```

### Development Installation

```bash
git clone https://github.com/yourusername/dynamical-systems.git
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
dynamical-systems \
  --ode linear \
  --ode-args n=2 \
  --ode-variables-t 0.0 \
  --ode-variables-x 0.0 1.0 \
  --ode-parameters 0 1 -1 0 \
  --solver rk4 \
  --solver-args h_max=0.01 \
  --job portrait \
  --job-args t_step=1.0 t_end=10.0 file=portrait.dat
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
job = job_factory.create(t_end=10.0, file='portrait.dat')

# Run simulation
job.run(ode, solver)
```

### Web Interface

```bash
# Start the web interface
python ui/app.py
```

Then open your browser to `http://localhost:5001`

## Available Components

### ODEs
- `linear`: Linear dynamical systems
- More systems available in the `src/ode/` directory

### Solvers
- `rk4`: 4th-order Runge-Kutta
- `dopri5`: Dormand-Prince 5th-order adaptive solver
- More solvers available in the `src/solver/` directory

### Jobs
- `portrait`: Generate phase portraits
- More analysis tools available in the `src/job/` directory

## Development

### Building from Source

The package uses C extensions for performance. To build:

```bash
python setup.py build_ext --inplace
```

### Running Tests

```bash
pytest
```

### Code Style

```bash
black .
flake8 .
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
