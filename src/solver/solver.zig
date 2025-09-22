const ds = @import("../dynamical_systems.zig");
const Argument = ds.Argument;
const ODE = ds.ode.ODE;

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const RK4 = @import("rk4.zig").RK4;

pub const Solver = struct {
    allocator: Allocator,
    args: []const Argument,
    dim: usize,
    data: *anyopaque,
    vtable: *const VTable,

    const VTable = struct {
        deinit: *const fn (*Solver) void,
        integrate: *const fn (*Solver, *const ODE, *f64, [*]f64, f64) anyerror!void,
    };

    pub inline fn deinit(self: *Solver) void {
        self.vtable.deinit(self);
    }
    pub inline fn integrate(
        self: *Solver,
        ode: *const ODE,
        t: *f64,
        x: [*]f64,
        t_end: f64,
    ) anyerror!void {
        try self.vtable.integrate(self, ode, t, x, t_end);
    }

    pub const Factory = struct {
        vtable: *const Factory.VTable,

        const VTable = struct {
            create: *const fn (Allocator, []const Argument) anyerror!Solver,
            getArguments: *const fn () []const Argument,
        };

        pub inline fn create(self: Factory, allocator: Allocator, args: []const Argument) anyerror!*Solver {
            const solver = try allocator.create(Solver);
            errdefer allocator.destroy(solver);
            solver.* = try self.vtable.create(allocator, args);
            errdefer solver.deinit();
            return solver;
        }
        pub fn destroy(self: Factory, solver: *Solver) void {
            _ = self;
            const allocator = solver.allocator;
            solver.deinit();
            allocator.destroy(solver);
        }
        pub fn getArguments(self: Factory) []const Argument {
            return self.vtable.getArguments();
        }
    };
};

test {
    _ = RK4;
}
