import dynamical_systems

ode_factory = dynamical_systems.OdeFactory(libpath="build/ode/linear.so")
print(ode_factory.get_argument_types())

ode = ode_factory.create_ode(n=2)
print(ode.get_name())
print(ode.get_arguments())

solver_factory = dynamical_systems.SolverFactory(libpath="build/solver/rk4.so")
print(solver_factory.get_argument_types())

solver = solver_factory.create_solver(h=0.01)
print(solver.get_name())
print(solver.get_arguments())
