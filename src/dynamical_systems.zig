//! By convention, root.zig is the root source file when making a library.
const std = @import("std");

pub const Argument = @import("dynamical_systems/Argument.zig");
pub const ode = @import("dynamical_systems/ode.zig");
pub const solver = @import("dynamical_systems/solver.zig");
pub const job = @import("dynamical_systems/job.zig");

test {
    _ = Argument;
    _ = ode;
    _ = solver;
    _ = job;
}
