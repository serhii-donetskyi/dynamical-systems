import dynamical_systems
import time
x = [0.0, 1.0]
p = [0, 1.0, -1.0, 0.0]
t_initial = 0.0 # Define the initial time

# Call with all three arguments, using keywords for clarity
ode = dynamical_systems.create_ode_linear(t=t_initial, x=x, p=p)

print(type(ode))
print(ode.t)
print(ode.n)
print(ode.x)
print(ode.p)
# You might want to add further assertions or calls here to test the ode object

# This call is already positional
solver = dynamical_systems.create_solver_rk4(0.01)
print(type(solver))

start_time = time.time()
dynamical_systems.phase_portrait(ode, solver, 1000000, 1_000_000_000)
end_time = time.time()
print(f"Phase portrait computation took {end_time - start_time:.2f} seconds")

print(ode.t, ode.x)

