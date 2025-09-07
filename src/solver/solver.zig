const ds = @import("../dynamical_systems.zig");
const Argument = ds.Argument;

const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn Solver(comptime vector_size: u64) type {
    const ODE = ds.ode.ODE(vector_size);
    return struct {
        pub const Self = @This();
        pub const T = ODE.T;

        capacity: u64,
        len: u64,
        args: []const Argument,
        allcator: Allocator,
        data: *anyopaque,
        vtable: *const VTable,

        const VTable = struct {
            destroy: *const fn (Self) void,
            prepare: *const fn (*Self, *const ODE) void,
            step: *const fn (
                noalias *const Self,
                noalias *const ODE,
                noalias *f64,
                noalias [*]T,
                f64,
            ) void,
        };

        pub inline fn destoy(self: Self) void {
            self.vtable.destroy(self);
        }
        pub inline fn prepare(self: *Self, ode: *const ODE) void {
            self.vtable.prepare(self, ode);
        }
        pub inline fn step(
            noalias self: *const Self,
            noalias ode: *const ODE,
            noalias t: *f64,
            noalias x: [*]T,
            t_end: f64,
        ) void {
            self.vtable.step(self, ode, t, x, t_end);
        }
    };
}

pub fn SolverFactory(comptime vector_size: u64) type {
    const SolverType = Solver(vector_size);
    return struct {
        pub const Self = @This();
        args: []const Argument,
        vtable: *const VTable,

        const VTable = struct {
            create: *const fn (Allocator, []const Argument) anyerror!SolverType,
        };

        pub inline fn create(self: Self, allocator: Allocator, args: []const Argument) anyerror!SolverType {
            return try self.vtable.create(allocator, args);
        }
        pub fn arguments(self: Self) []const Argument {
            return self.args;
        }
    };
}

comptime {
    const ODE = ds.ode.ODE;
    for ([_]usize{ 0, 1, 2, 4 }) |i| {
        std.debug.assert(Solver(i).T == ODE(i).T);
    }
}
