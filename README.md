# Dynamical Systems

A high-performance Zig library for numerical analysis of dynamical systems with a command-line interface.

## Features

- **Fast Zig implementations** for numerical integration
- **Multiple ODE solvers** (RK4, DOPRI5)
- **Various dynamical systems** (Linear, Spherical Pendulum)
- **Analysis tools** for phase portraits and system analysis
- **Command-line interface** for quick analysis
- **Modular architecture** with dynamic library loading

## Installation

### Building from Source

```bash
git clone https://github.com/serhii-donetskyi/dynamical-systems.git
cd dynamical-systems
zig build --release=fast -Doptimize=ReleaseFast
```

The executable will be installed to `zig-out/bin/dynamical-systems`.

**Note for macOS users:** If you encounter a security warning when running the executable, remove the quarantine attribute:
```bash
xattr -rd com.apple.quarantine zig-out
```

## Requirements

- Zig compiler (0.15.1+)

## Quick Start

### Command Line Usage

```bash
# Generate a phase portrait for a linear system
zig-out/bin/dynamical-systems run \
  -ode linear \
  -ode-arg n=2 \
  -t 0.0 \
  -x 0.0 -x 1.0 \
  -p 0 -p 1 -p -1 -p 0 \
  -solver rk4 \
  -solver-arg h_max=0.01 \
  -job portrait \
  -job-arg t_step=0.1 -job-arg t_end=10.0

# List available components
zig-out/bin/dynamical-systems list-odes
zig-out/bin/dynamical-systems list-solvers
zig-out/bin/dynamical-systems list-jobs

# Get arguments for a component
zig-out/bin/dynamical-systems get-ode-args linear
zig-out/bin/dynamical-systems get-solver-args rk4
zig-out/bin/dynamical-systems get-job-args portrait
```

## Development

### Building

```bash
# Build executable and libraries
zig build

# Run tests
zig build test

# Run the executable
zig build run
```

### Project Structure

```
dynamical-systems/
├── src/
│   ├── dynamical_systems/      # Core Zig library
│   │   ├── ode/               # ODE implementations
│   │   ├── solver/            # Solver implementations
│   │   └── job/               # Analysis job implementations
│   ├── cli/                   # CLI argument parsing
│   ├── cli.zig                # CLI implementation
│   └── main.zig               # Entry point
├── tests/                     # Test suite
├── build.zig                  # Zig build configuration
└── build.zig.zon             # Zig package manifest
```

### Architecture

The project uses a modular architecture where components (ODEs, solvers, jobs) are compiled as dynamic libraries and loaded at runtime. This allows for easy extension without recompiling the main executable.

Components are discovered from the `zig-out/lib/` directory structure:
- `zig-out/lib/ode/` - ODE implementations
- `zig-out/lib/solver/` - Solver implementations
- `zig-out/lib/job/` - Job implementations

## License

MIT License - see LICENSE file for details.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Run the test suite (`zig build test`)
5. Submit a pull request

## Citation

If you use this package in academic work, please cite:

```bibtex
@software{dynamical_systems,
  title = {Dynamical Systems: A Zig Library for Numerical Analysis},
  author = {Serhii Donetskyi},
  url = {https://github.com/serhii-donetskyi/dynamical-systems},
  year = {2025}
}
```
