const ds = @import("../dynamical_systems.zig");
const Argument = ds.Argument;
const ODE = ds.ode.ODE;
const Solver = ds.solver.Solver;

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Data = struct {
    y: []f64,
    k1: []f64,
    k2: []f64,
    k3: []f64,
    k4: []f64,
};

pub fn create(allocator: Allocator, args: []const Argument) !Solver {
    return .{
        .allocator = allocator,
        .args = args,
        .vtable = &.{
            .destroy = destroy,
            .prepare = prepare,
            .step = step,
        },
    };
}

fn destroy(self: Solver) void {
    self.allocator.free(self.args);
}

fn prepare(self: *Solver, ode: *const ODE) void {
    var data: *Data = @ptrCast(@alignCast(self.data));
    if (data.y.len != ode.x_size) {
        self.allocator.free(data.y);
        self.allocator.free(data.k1);
        self.allocator.free(data.k2);
        self.allocator.free(data.k3);
        self.allocator.free(data.k4);
    }
}

fn step(
    noalias self: *const Solver,
    noalias ode: *const ODE,
    noalias t: *f64,
    noalias x: [*]f64,
    t_end: f64,
) void {}
