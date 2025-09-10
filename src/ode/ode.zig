const ds = @import("../dynamical_systems.zig");
const Argument = ds.Argument;
const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Linear = @import("linear.zig").Linear;

pub fn ODE(comptime vector_len: usize) type {
    return struct {
        pub const Self = @This();
        pub const v_len = vector_len;
        pub const T = if (v_len == 0) f64 else @Vector(v_len, f64);

        allocator: Allocator,
        args: []const Argument,
        x_dim: u64,
        p_dim: u64,
        t: f64,
        x: []T,
        p: []T,
        vtable: *const VTable,

        pub const VTable = struct {
            deinit: *const fn (*Self) void,
            calc: *const fn (*const Self, f64, [*]const T, [*]T) void,
            getT: *const fn (Self) f64,
            getX: *const fn (Self, usize) f64,
            getP: *const fn (Self, usize) f64,
            setT: *const fn (*Self, f64) void,
            setX: *const fn (*Self, []const f64) void,
            setP: *const fn (*Self, []const f64) void,
        };

        pub inline fn deinit(self: *Self) void {
            self.vtable.deinit(self);
        }
        pub inline fn calc(self: *const Self, t: f64, x: [*]const T, dxdt: [*]T) void {
            self.vtable.calc(self, t, x, dxdt);
        }
        pub inline fn getXDim(self: Self) usize {
            return self.x_dim;
        }
        pub inline fn getPDim(self: Self) usize {
            return self.p_dim;
        }
        pub inline fn getT(self: Self) f64 {
            return self.vtable.getT(self);
        }
        pub inline fn getX(self: Self, i: usize) f64 {
            return self.vtable.getX(self, i);
        }
        pub inline fn getP(self: Self, i: usize) f64 {
            return self.vtable.getP(self, i);
        }
        pub inline fn setT(self: *Self, t: f64) void {
            self.vtable.setT(self, t);
        }
        pub inline fn setX(self: *Self, x: []const f64) void {
            self.vtable.setX(self, x);
        }
        pub inline fn setP(self: *Self, p: []const f64) void {
            self.vtable.setP(self, p);
        }
    };
}

pub fn ODEFactory(comptime vector_len: usize) type {
    const ODEType = ODE(vector_len);
    return struct {
        pub const Self = @This();

        args: []const Argument,
        vtable: *const VTable,

        const VTable = struct {
            create: *const fn (Allocator, []const Argument) anyerror!ODEType,
        };

        pub fn create(self: Self, allocator: Allocator, args: []const Argument) anyerror!*ODEType {
            const ode = try allocator.create(ODEType);
            errdefer allocator.destroy(ode);
            ode.* = try self.vtable.create(allocator, args);
            errdefer ode.deinit();
            return ode;
        }
        pub fn destroy(self: Self, ode: *ODEType) void {
            _ = self;
            const allocator = ode.allocator;
            ode.deinit();
            allocator.destroy(ode);
        }
        pub fn getArguments(self: Self) []const Argument {
            return self.args;
        }
    };
}

comptime {
    std.debug.assert(ODE(0).T == f64);
    for ([_]u64{ 1, 2, 4 }) |i| {
        std.debug.assert(ODE(i).T == @Vector(i, f64));
    }
}

test {
    _ = Linear;
}
