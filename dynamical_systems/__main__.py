import argparse
from . import components

def parse_component_args(arg: str):    
    for k, v in [arg.split('=', 1)]:
        return {'name': k, 'value': v}

def parse_args():
    """Parse command line arguments for dynamical systems"""
    parser = argparse.ArgumentParser(
        description='Dynamical Systems Package - Numerical analysis of dynamical systems',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python -m dynamical_systems \
    --ode linear \
    --ode-args n=2 \
    --ode-variables-t 0.0 \
    --ode-variables-x 0.0 1.0 \
    --ode-parameters 0 1 -1 0 \
    --solver rk4 \
    --solver-args h_max=0.01 \
    --job portrait \
    --job-args t_end=10.0 file=portrait.dat
        """
    )
    
    # ODE specification
    parser.add_argument(
        '--ode', 
        type=str, 
        required=True,
        help='Name of the ODE to use (e.g., linear, lorenz, vanderpol)'
    )
    
    # ODE arguments as key:value pairs
    parser.add_argument(
        '--ode-args',
        type=parse_component_args,
        nargs='*',
        help='ODE arguments as key=value pairs (e.g., name1=value1 name2=value2)'
    )
    
    # Time variable
    parser.add_argument(
        '--ode-variables-t',
        type=float,
        required=True,
        help='Initial time value (e.g., 0.0)'
    )
    
    # State variables
    parser.add_argument(
        '--ode-variables-x',
        type=float,
        required=True,
        nargs='*',
        help='Initial state variables as space-separated floats (e.g., 1.0 2.0 3.0)'
    )
    
    # Parameters
    parser.add_argument(
        '--ode-parameters',
        type=float,
        default=[],
        nargs='*',
        help='ODE parameters as space-separated floats (e.g., 1.0 2.0 3.0)'
    )
    
    # Optional solver arguments
    parser.add_argument(
        '--solver',
        type=str,
        required=True,
        help='Solver to use (default: rk4)'
    )
    
    parser.add_argument(
        '--solver-args',
        type=parse_component_args,
        default=[],
        nargs='*',
        help='Solver arguments as key=value pairs (e.g., name1=value1 name2=value2)'
    )

    parser.add_argument(
        '--job',
        type=str,
        required=True,
        help='Job to use (default: portrait)'
    )

    parser.add_argument(
        '--job-args',
        type=parse_component_args,
        default=[],
        nargs='*',
        help='Job arguments as key=value pairs (e.g., name1=value1 name2=value2)'
    )
    
    return parser.parse_args()

def main():
    """Main entry point for the dynamical systems package"""
    args = parse_args()
    
    for component in components:
        name = getattr(args, f'{component}')
        if name not in components.get(component, {}):
            available_components = list(components.get(component, {}))
            print(f"Error: {component} '{name}' not found.")
            if available_components:
                print(f"Available {component}s: {', '.join(available_components)}")
            else:
                print(f"No {component}s available in the system.")
            raise ValueError(f"{component} '{name}' not found.")
    
    ode_f = components['ode'][args.ode]
    solver_f = components['solver'][args.solver]
    job_f = components['job'][args.job]
    
    ode_kwargs = {
        d['name']: d['value']
        for d in args.ode_args
    }
    for arg in ode_f.get_argument_types():
        ode_kwargs[arg['name']] = arg['type'](ode_kwargs[arg['name']])
    
    solver_kwargs = {
        d['name']: d['value']
        for d in args.solver_args
    }
    for arg in solver_f.get_argument_types():
        solver_kwargs[arg['name']] = arg['type'](solver_kwargs[arg['name']])
    
    job_kwargs = {
        d['name']: d['value']
        for d in args.job_args
    }
    for arg in job_f.get_argument_types():
        job_kwargs[arg['name']] = arg['type'](job_kwargs[arg['name']])

    ode = ode_f.create(**ode_kwargs) \
        .set_t(args.ode_variables_t) \
        .set_x(args.ode_variables_x) \
        .set_p(args.ode_parameters)
    solver = solver_f.create(**solver_kwargs)
    job = job_f.create(**job_kwargs)
    job.run(ode, solver)

if __name__ == "__main__":
    main()
