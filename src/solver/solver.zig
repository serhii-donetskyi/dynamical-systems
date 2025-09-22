const ds = @import("../dynamical_systems.zig");
const Argument = ds.Argument;
const ODE = ds.ode.ODE;

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const rk4 = @import("rk4.zig");
pub const RK4 = rk4.RK4;

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
            init: *const fn (Allocator, []const Argument) anyerror!Solver,
            getArguments: *const fn () []const Argument,
        };

        pub inline fn init(self: Factory, allocator: Allocator, args: []const Argument) anyerror!Solver {
            return self.vtable.init(allocator, args);
        }
        pub inline fn getArguments(self: Factory) []const Argument {
            return self.vtable.getArguments();
        }
    };
};

test {
    std.testing.refAllDecls(@This());
}
