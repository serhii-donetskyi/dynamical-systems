const ds = @import("../dynamical_systems.zig");
const Argument = ds.Argument;
const ODE = ds.ode.ODE;

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Solver = struct {
    n: u64,
    args: []const Argument,
    allocator: Allocator,
    data: *anyopaque,
    vtable: *const VTable,

    const VTable = struct {
        destroy: *const fn (Solver) void,
        prepare: *const fn (*Solver, *const ODE) void,
        step: *const fn (
            noalias *const Solver,
            noalias *const ODE,
            noalias *f64,
            noalias [*]f64,
            f64,
        ) void,
    };

    pub inline fn destroy(self: Solver) void {
        self.vtable.destroy(self);
    }
    pub inline fn prepare(self: *Solver, ode: *const ODE) void {
        self.vtable.prepare(self, ode);
    }
    pub inline fn step(
        noalias self: *const Solver,
        noalias ode: *const ODE,
        noalias t: *f64,
        noalias x: [*]f64,
        t_end: f64,
    ) void {
        self.vtable.step(self, ode, t, x, t_end);
    }
    pub fn arguments(self: Solver) []const Argument {
        return self.args;
    }
};

pub const SolverFactory = struct {
    args: []const Argument,
    vtable: *const VTable,

    const VTable = struct {
        create: *const fn (Allocator, []const Argument) anyerror!Solver,
    };

    pub inline fn create(self: SolverFactory, allocator: Allocator, args: []const Argument) anyerror!Solver {
        return try self.vtable.create(allocator, args);
    }
    pub fn arguments(self: SolverFactory) []const Argument {
        return self.args;
    }
};
