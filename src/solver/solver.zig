const ds = @import("../dynamical_systems.zig");
const Argument = ds.Argument;

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const RK4 = @import("rk4.zig").RK4;

pub fn Solver(comptime vector_size: u64) type {
    const ODE = ds.ode.ODE(vector_size);
    return struct {
        pub const Self = @This();
        pub const T = ODE.T;

        dim: u64,
        allocator: Allocator,
        data: *anyopaque,
        args: []const Argument,
        vtable: *const VTable,

        const VTable = struct {
            destroy: *const fn (Self) void,
            integrate: *const fn (
                *Self,
                *const ODE,
                *f64,
                [*]T,
                f64,
            ) anyerror!void,
        };

        pub inline fn destroy(self: Self) void {
            self.vtable.destroy(self);
        }
        pub inline fn integrate(
            self: *Self,
            ode: *const ODE,
            t: *f64,
            x: [*]T,
            t_end: f64,
        ) anyerror!void {
            try self.vtable.integrate(self, ode, t, x, t_end);
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
    for ([_]u64{ 0, 1, 2, 4 }) |i| {
        std.debug.assert(Solver(i).T == ODE(i).T);
    }
}

test {
    _ = RK4;
}
