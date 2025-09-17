//! By convention, root.zig is the root source file when making a library.
const std = @import("std");
const builtin = @import("builtin");

pub const Argument = @import("Argument.zig");
pub const ArgParser = @import("ArgParser.zig");
pub const ode = @import("ode/ode.zig");
pub const solver = @import("solver/solver.zig");

test {
    _ = Argument;
    _ = ArgParser;
    _ = ode;
    _ = solver;
}
