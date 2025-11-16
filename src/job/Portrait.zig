const std = @import("std");
const ds = @import("../dynamical_systems.zig");
const Argument = ds.Argument;
const Job = ds.job.Job;
const ODE = ds.ode.ODE;
const Solver = ds.solver.Solver;
const Allocator = std.mem.Allocator;
const Portrait = @This();

pub fn init(allocator: Allocator, t_step: f64, t_end: f64) !Job {
    const args = try allocator.alloc(Argument, 2);
    errdefer allocator.free(args);

    args[0] = .{ .name = "t_step", .value = .{ .r = t_step } };
    args[1] = .{ .name = "t_end", .value = .{ .r = t_end } };

    return .{
        .allocator = allocator,
        .args = args,
    };
}

pub fn deinit(self: *Job) void {
    self.allocator.free(self.args);
}

pub fn run(self: *Job, solver: *Solver, ode: *const ODE) void {}
