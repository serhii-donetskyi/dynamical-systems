const ds = @import("../dynamical_systems.zig");
const Argument = ds.Argument;

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Linear = @import("Linear.zig");

pub const ODE = struct {
    allocator: Allocator,
    args: []const Argument,
    t: f64,
    x: []f64,
    p: []f64,
    vtable: *const VTable,

    pub const VTable = struct {
        deinit: *const fn (*ODE) void,
        calc: *const fn (*const ODE, f64, [*]const f64, [*]f64) void,
    };

    pub inline fn deinit(self: *ODE) void {
        self.vtable.deinit(self);
    }
    pub inline fn calc(self: *const ODE, t: f64, x: [*]const f64, dxdt: [*]f64) void {
        self.vtable.calc(self, t, x, dxdt);
    }
    pub inline fn getXDim(self: ODE) usize {
        return self.x.len;
    }
    pub inline fn getPDim(self: ODE) usize {
        return self.p.len;
    }
    pub inline fn getT(self: ODE) f64 {
        return self.t;
    }
    pub inline fn getX(self: ODE, i: usize) f64 {
        return self.x[i];
    }
    pub inline fn getP(self: ODE, i: usize) f64 {
        return self.p[i];
    }
    pub inline fn setT(self: *ODE, t: f64) void {
        self.t = t;
    }
    pub inline fn setX(self: *ODE, i: usize, x: f64) void {
        if (i < self.x.len) self.x[i] = x;
    }
    pub inline fn setP(self: *ODE, i: usize, p: f64) void {
        if (i < self.p.len) self.p[i] = p;
    }

    pub const Factory = struct {
        const Error = error{
            MissingArgument,
            InvalidArgument,
        };

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
