const ds = @import("../dynamical_systems.zig");
const Argument = ds.Argument;

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const RK4 = @import("rk4.zig").RK4;

pub fn Solver(comptime vector_size: usize) type {
    const ODE = ds.ode.ODE(vector_size);
    return struct {
        pub const Self = @This();
        pub const T = ODE.T;

        allocator: Allocator,
        args: []const Argument,
        dim: usize,
        data: *anyopaque,
        vtable: *const VTable,

        const VTable = struct {
            deinit: *const fn (*Self) void,
            integrate: *const fn (*Self, *const ODE, *f64, [*]T, f64) anyerror!void,
        };

        pub inline fn deinit(self: *Self) void {
            self.vtable.deinit(self);
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

        pub inline fn create(self: Self, allocator: Allocator, args: []const Argument) anyerror!*SolverType {
            const solver = try allocator.create(SolverType);
            errdefer allocator.destroy(solver);
            solver.* = try self.vtable.create(allocator, args);
            errdefer solver.deinit();
            return solver;
        }
        pub fn destroy(self: Self, solver: *SolverType) void {
            _ = self;
            const allocator = solver.allocator;
            solver.deinit();
            allocator.destroy(solver);
        }
        pub fn getArguments(self: Self) []const Argument {
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
