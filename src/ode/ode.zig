const ds = @import("../dynamical_systems.zig");
const Argument = ds.Argument;
const std = @import("std");
const Allocator = std.mem.Allocator;

pub const linear = @import("linear.zig");

pub fn ODE(comptime v_size: u64) type {
    return struct {
        pub const Self = @This();
        pub const vector_size = v_size;
        pub const T = if (vector_size == 0) f64 else @Vector(vector_size, f64);

        x_size: u64,
        p_size: u64,
        t: f64,
        x: []T,
        p: []T,
        args: []const Argument,
        allocator: Allocator,
        vtable: *const VTable,

        pub const VTable = struct {
            destroy: *const fn (Self) void,
            calc: *const fn (noalias *const Self, f64, noalias [*]const T, noalias [*]T) void,
        };

        pub inline fn destroy(self: Self) void {
            self.vtable.destroy(self);
        }
        pub inline fn calc(noalias self: *const Self, t: f64, noalias x: [*]const T, noalias dxdt: [*]T) void {
            self.vtable.calc(self, t, x, dxdt);
        }
        pub inline fn get_x_len(self: Self) u64 {
            return self.x.len;
        }
        pub inline fn get_p_len(self: Self) u64 {
            return self.p.len;
        }
        pub inline fn get_x_size(self: Self) u64 {
            return self.x_size;
        }
        pub inline fn get_p_size(self: Self) u64 {
            return self.p_size;
        }
        pub fn get_t(self: Self) f64 {
            return self.t;
        }
        pub fn get_x(self: Self, i: u64) f64 {
            if (i < self.x_size()) {
                if (comptime 0 == vector_size)
                    return self.x[i]
                else
                    return self.x[i / vector_size][i % vector_size];
            } else return 0.0;
        }
        pub fn get_p(self: Self, i: u64) f64 {
            if (i < self.get_p_size()) {
                if (comptime 0 == vector_size)
                    return self.p[i]
                else
                    return self.p[i / vector_size][i % vector_size];
            } else return 0.0;
        }
        pub fn get(self: Self) struct { t: f64, x: []const T, p: []const T } {
            return .{ .t = self.t, .x = self.x, .p = self.p };
        }
        pub fn set(
            self: *Self,
            state: struct { t: ?f64 = null, x: ?[]const f64 = null, p: ?[]const f64 = null },
        ) void {
            if (state.t) |t| self.t = t;
            if (state.x) |x| {
                const n = if (x.len > self.x_size) self.x_size else x.len;
                for (0..n) |i| {
                    if (comptime vector_size == 0)
                        self.x[i] = x[i]
                    else
                        self.x[i / vector_size][i % vector_size] = x[i];
                }
            }
            if (state.p) |p| {
                const m = if (p.len > self.p_size) self.p_size else p.len;
                for (0..m) |i| {
                    if (comptime vector_size == 0)
                        self.p[i] = p[i]
                    else
                        self.p[i / vector_size][i % vector_size] = p[i];
                }
            }
        }
    };
}

pub fn ODEFactory(comptime vector_size: u64) type {
    const ODEType = ODE(vector_size);
    return struct {
        pub const Self = @This();
        args: []const Argument,
        vtable: *const VTable,

        const VTable = struct {
            create: *const fn (Allocator, []const Argument) anyerror!ODEType,
        };

        pub inline fn create(self: Self, allocator: Allocator, args: []const Argument) anyerror!ODEType {
            return try self.vtable.create(allocator, args);
        }
        pub fn arguments(self: Self) []const Argument {
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
    _ = linear;
}
