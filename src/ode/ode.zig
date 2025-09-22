const ds = @import("../dynamical_systems.zig");
const Argument = ds.Argument;

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const linear = @import("linear.zig");
pub const Linear = linear.Linear;

pub const ODE = struct {
    allocator: Allocator,
    args: []const Argument,
    x_dim: usize,
    p_dim: usize,
    t: f64,
    x: []f64,
    p: []f64,
    vtable: *const VTable,

    pub const VTable = struct {
        deinit: *const fn (*ODE) void,
        calc: *const fn (*const ODE, f64, [*]const f64, [*]f64) void,
        getT: *const fn (ODE) f64,
        getX: *const fn (ODE, usize) f64,
        getP: *const fn (ODE, usize) f64,
        setT: *const fn (*ODE, f64) void,
        setX: *const fn (*ODE, []const f64) void,
        setP: *const fn (*ODE, []const f64) void,
    };

    pub inline fn deinit(self: *ODE) void {
        self.vtable.deinit(self);
    }
    pub inline fn calc(self: *const ODE, t: f64, x: [*]const f64, dxdt: [*]f64) void {
        self.vtable.calc(self, t, x, dxdt);
    }
    pub inline fn getXDim(self: ODE) usize {
        return self.x_dim;
    }
    pub inline fn getPDim(self: ODE) usize {
        return self.p_dim;
    }
    pub inline fn getT(self: ODE) f64 {
        return self.vtable.getT(self);
    }
    pub inline fn getX(self: ODE, i: usize) f64 {
        return self.vtable.getX(self, i);
    }
    pub inline fn getP(self: ODE, i: usize) f64 {
        return self.vtable.getP(self, i);
    }
    pub inline fn setT(self: *ODE, t: f64) void {
        self.vtable.setT(self, t);
    }
    pub inline fn setX(self: *ODE, x: []const f64) void {
        self.vtable.setX(self, x);
    }
    pub inline fn setP(self: *ODE, p: []const f64) void {
        self.vtable.setP(self, p);
    }

    pub const Factory = struct {
        vtable: *const Factory.VTable,

        const VTable = struct {
            init: *const fn (Allocator, []const Argument) anyerror!ODE,
            getArguments: *const fn () []const Argument,
        };

        pub inline fn init(self: Factory, allocator: Allocator, args: []const Argument) anyerror!ODE {
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
