import dynamical_systems

odeFactory = dynamical_systems.OdeFactory(libpath="build/ode/linear.so")

print("Available attributes and methods:")
print(dir(odeFactory))
print(odeFactory.get_argument_types())

ode = odeFactory.create_ode(n=2)

print(ode.get_name())
print(ode.get_arguments())
