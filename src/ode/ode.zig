const ds = @import("../dynamical_systems.zig");
const Argument = ds.Argument;
const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Linear = @import("Linear.zig");

pub const ODE = struct {
    t: f64,
    x: []f64,
    p: []f64,
    args: []const Argument,
    allocator: Allocator,
    vtable: *const VTable,

    pub const VTable = struct {
        destroy: *const fn (ODE) void,
        calc: *const fn (noalias *const ODE, f64, noalias [*]const f64, noalias [*]f64) void,
    };

    pub inline fn destroy(self: ODE) void {
        self.vtable.destroy(self);
    }
    pub inline fn calc(
        noalias self: *const ODE,
        t: f64,
        noalias x: [*]const f64,
        noalias dxdt: [*]f64,
    ) void {
        self.vtable.calc(self, t, x, dxdt);
    }
    pub fn set(self: *ODE, state: struct { t: ?f64 = null, x: ?[]const f64 = null, p: ?[]const f64 = null }) void {
        if (state.t) |t| {
            self.t = t;
        }
        if (state.x) |x| {
            const n = (if (self.x.len < x.len) self.x.len else x.len);
            for (0..n) |i| {
                self.x[i] = x[i];
            }
        }
        if (state.p) |p| {
            const n = (if (self.p.len < p.len) self.p.len else p.len);
            for (0..n) |i| {
                self.p[i] = p[i];
            }
        }
    }
    pub fn get(self: ODE) struct { t: f64, x: []const f64, p: []const f64 } {
        return .{ .t = self.t, .x = self.x, .p = self.p };
    }
    pub fn arguments(self: ODE) []const Argument {
        return self.args;
    }
};

pub const ODEFactory = struct {
    args: []const Argument,
    vtable: *const VTable,

    const VTable = struct {
        create: *const fn (Allocator, []const Argument) anyerror!ODE,
    };

    pub inline fn create(self: ODEFactory, allocator: Allocator, args: []const Argument) anyerror!ODE {
        return try self.vtable.create(allocator, args);
    }
    pub fn arguments(self: ODE) []const Argument {
        return self.args;
    }
};

test {
    _ = Linear;
}
