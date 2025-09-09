const ds = @import("../dynamical_systems.zig");
const Argument = ds.Argument;

const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn Linear(comptime v_len: usize) type {
    const ODEFactory = ds.ode.ODEFactory(v_len);
    const ODE = ds.ode.ODE(v_len);
    const vector_len = ODE.vector_len;
    return struct {
        pub const T = ODE.T;

        pub fn init(allocator: Allocator, n: u64) !ODE {
            const t = 0.0;

            const args = try allocator.alloc(Argument, 1);
            errdefer allocator.free(args);
            args[0] = .{ .name = "n", .value = .{ .u = n } };

            const x_dim = n;
            const x_len = if (vector_len == 0) x_dim else if (x_dim % vector_len > 0) x_dim / vector_len + 1 else x_dim / vector_len;
            const x = try allocator.alloc(T, x_len);
            errdefer allocator.free(x);
            for (0..x_len) |i| {
                x[i] = if (vector_len == 0) 0.0 else @splat(0.0);
            }

            const p_dim = x_dim * x_dim;
            const p_len = x_dim * x_len;
            const p = try allocator.alloc(T, p_len);
            errdefer allocator.free(p);
            for (0..p_len) |i| {
                p[i] = if (vector_len == 0) 0.0 else @splat(0.0);
            }

            return .{
                .allocator = allocator,
                .args = args,
                .x_dim = x_dim,
                .p_dim = p_dim,
                .t = t,
                .x = x,
                .p = p,
                .vtable = &.{
                    .deinit = deinit,
                    .calc = calc,
                    .getT = getT,
                    .getX = getX,
                    .getP = getP,
                    .setT = setT,
                    .setX = setX,
                    .setP = setP,
                },
            };
        }

        fn deinit(self: *ODE) void {
            self.allocator.free(self.args);
            self.allocator.free(self.x);
            self.allocator.free(self.p);
        }
        fn calc(self: *const ODE, t: f64, x: [*]const T, dxdt: [*]T) void {
            @setRuntimeSafety(false);
            @setFloatMode(.optimized);
            _ = t;
            if (comptime vector_len == 0) {
                for (0..self.x_dim) |i| {
                    for (0..self.x_dim) |j| {
                        dxdt[i] += self.p[i * self.x_dim + j] * x[j];
                    }
                }
            } else {
                for (0..self.x_dim) |i| {
                    var tmp = @as(T, @splat(0.0));
                    for (0..self.x.len) |j| {
                        tmp = @mulAdd(T, self.p[i * self.x.len + j], x[j], tmp);
                    }
                    dxdt[i / vector_len][i % vector_len] = @reduce(.Add, tmp);
                }
            }
        }
        fn getT(self: ODE) f64 {
            return self.t;
        }
        fn getX(self: ODE, i: usize) f64 {
            return if (comptime vector_len == 0)
                self.x[i]
            else
                self.x[i / vector_len][i % vector_len];
        }
        fn getP(self: ODE, i: usize) f64 {
            if (comptime vector_len == 0) {
                return self.p[i];
            } else {
                const cluster_idx = i / self.x_dim;
                const cluster_offset = i % self.x_dim;
                const idx = cluster_idx * self.x.len + cluster_offset / vector_len;
                const offset = cluster_offset % vector_len;
                return self.p[idx][offset];
            }
        }
        fn setT(self: *ODE, t: f64) void {
            self.t = t;
        }
        fn setX(self: *ODE, x: []const f64) void {
            for (0..self.x.len) |i|
                self.x[i] = if (vector_len == 0) 0.0 else @splat(0.0);
            const n = if (self.x_dim > x.len) x.len else self.x_dim;
            for (0..n) |i| {
                if (comptime vector_len == 0)
                    self.x[i] = if (i < x.len) x[i] else 0.0
                else
                    self.x[i / vector_len][i % vector_len] = if (i < x.len) x[i] else 0.0;
            }
        }
        fn setP(self: *ODE, p: []const f64) void {
            for (0..self.p.len) |i|
                self.p[i] = if (vector_len == 0) 0.0 else @splat(0.0);
            const n = if (self.p_dim > p.len) p.len else self.p_dim;
            for (0..n) |i| {
                if (comptime vector_len == 0)
                    self.p[i] = if (i < p.len) p[i] else 0.0
                else {
                    const cluster_idx = i / self.x_dim;
                    const cluster_offset = i % self.x_dim;
                    const idx = cluster_idx * self.x.len + cluster_offset / vector_len;
                    const offset = cluster_offset % vector_len;
                    self.p[idx][offset] = if (i < p.len) p[i] else 0.0;
                }
            }
        }

        const arguments = [_]Argument{.{
            .name = "n",
            .value = .{ .u = 2 },
        }};
        fn create(allocator: Allocator, args: []const Argument) !ODE {
            return try init(allocator, args[0].value.u);
        }
        pub const factory = ODEFactory{
            .args = &arguments,
            .vtable = &.{
                .create = create,
            },
        };
    };
}

comptime {
    _ = Linear(0);
    _ = Linear(1);
    _ = Linear(2);
    _ = Linear(4);
}

test "Factory" {
    const n = 2;
    const factory = Linear(0).factory;

    var linear = try factory.create(
        std.testing.allocator,
        &[_]Argument{.{
            .name = "n",
            .value = .{ .u = n },
        }},
    );
    defer factory.destroy(linear);

    const t = @as(f64, 0.0);
    const x = &[_]f64{ 1.0, 1.0 };
    const p = &[_]f64{ 0.0, 1.0, -1.0, 0.0 };
    var dxdt = [_]f64{ 0.0, 0.0 };

    linear.setT(t);
    linear.setX(x);
    linear.setP(p);

    linear.calc(t, linear.x.ptr, &dxdt);

    try std.testing.expect(2 == linear.x.len);
    try std.testing.expect(4 == linear.p.len);
    try std.testing.expect(1.0 == dxdt[0]);
    try std.testing.expect(-1.0 == dxdt[1]);
}

test "Vector 0, dim 2" {
    const n = 2;
    const LinearType = Linear(0);

    var linear = try LinearType.init(std.testing.allocator, n);
    defer linear.deinit();
    const t = @as(f64, 0.0);
    const x = &[_]f64{ 1.0, 1.0 };
    const p = &[_]f64{ 0.0, 1.0, -1.0, 0.0 };
    var dxdt = [_]f64{ 0.0, 0.0 };

    linear.setT(t);
    linear.setX(x);
    linear.setP(p);
    linear.calc(t, linear.x.ptr, &dxdt);

    linear.calc(t, linear.x.ptr, &dxdt);

    try std.testing.expect(2 == linear.x.len);
    try std.testing.expect(4 == linear.p.len);
    try std.testing.expect(1.0 == dxdt[0]);
    try std.testing.expect(-1.0 == dxdt[1]);
}

test "Vector 2, dim 2" {
    const n = 2;
    const LinearType = Linear(2);

    var linear = try LinearType.init(std.testing.allocator, n);
    defer linear.deinit();
    const t = @as(f64, 0.0);
    const x = &[_]f64{ 1.0, 1.0 };
    const p = &[_]f64{ 0.0, 1.0, -1.0, 0.0 };
    var dxdt = [_]LinearType.T{.{ 0.0, 0.0 }};

    linear.setT(t);
    linear.setX(x);
    linear.setP(p);
    linear.calc(t, linear.x.ptr, &dxdt);
    linear.calc(t, linear.x.ptr, &dxdt);

    try std.testing.expect(1 == linear.x.len);
    try std.testing.expect(2 == linear.p.len);
    try std.testing.expect(1.0 == dxdt[0][0]);
    try std.testing.expect(-1.0 == dxdt[0][1]);
}

test "Vector 2, dim 5" {
    const n = 5;
    const LinearType = Linear(2);

    var linear = try LinearType.init(std.testing.allocator, n);
    defer linear.deinit();
    const t = @as(f64, 0.0);
    const x = &[_]f64{ 1.0, 1.0, 0.0, 0.0, 0.0 };
    const p = &[_]f64{ 0.0, 1.0, 0.0, 0.0, 0.0, -1.0, 0.0, 0.0, 0.0, 0.0 };
    var dxdt = [_]LinearType.T{ .{ 0.0, 0.0 }, .{ 0.0, 0.0 }, .{ 0.0, -7.0 } };

    linear.setT(t);
    linear.setX(x);
    linear.setP(p);
    linear.calc(t, linear.x.ptr, &dxdt);
    linear.calc(t, linear.x.ptr, &dxdt);

    try std.testing.expect(3 == linear.x.len);
    try std.testing.expect(15 == linear.p.len);
    try std.testing.expect(1.0 == dxdt[0][0]);
    try std.testing.expect(-1.0 == dxdt[0][1]);
    try std.testing.expect(0.0 == dxdt[1][0]);
    try std.testing.expect(0.0 == dxdt[1][1]);
    try std.testing.expect(0.0 == dxdt[2][0]);
    try std.testing.expect(-7.0 == dxdt[2][1]);
}

test "Vector 4, dim 2" {
    const n = 2;
    const LinearType = Linear(4);

    var linear = try LinearType.init(std.testing.allocator, n);
    defer linear.deinit();
    const t = @as(f64, 0.0);
    const x = &[_]f64{ 1.0, 1.0 };
    const p = &[_]f64{ 0.0, 1.0, -1.0, 0.0 };
    var dxdt = [_]LinearType.T{.{ 0.0, 0.0, 17.0, 19.0 }};

    linear.setT(t);
    linear.setX(x);
    linear.setP(p);
    linear.calc(linear.t, linear.x.ptr, &dxdt);

    try std.testing.expect(1 == linear.x.len);
    try std.testing.expect(2 == linear.p.len);
    try std.testing.expect(1.0 == dxdt[0][0]);
    try std.testing.expect(-1.0 == dxdt[0][1]);
    try std.testing.expect(17.0 == dxdt[0][2]);
    try std.testing.expect(19.0 == dxdt[0][3]);
}

test "Vector 4, dim 5" {
    const n = 5;
    const LinearType = Linear(4);

    var linear = try LinearType.init(std.testing.allocator, n);
    defer linear.deinit();
    const t = @as(f64, 0.0);
    const x = &[_]f64{ 1.0, 1.0, 0.0, 0.0, 0.0 };
    const p = &[_]f64{ 0.0, 1.0, 0.0, 0.0, 0.0, -1.0, 0.0, 0.0, 0.0, 0.0 };
    var dxdt = [_]LinearType.T{ .{ 0.0, 0.0, 0.0, 0.0 }, .{ 0.0, 3.0, 5.0, 7.0 } };

    linear.setT(t);
    linear.setX(x);
    linear.setP(p);
    linear.calc(t, linear.x.ptr, &dxdt);
    linear.calc(t, linear.x.ptr, &dxdt);

    try std.testing.expect(2 == linear.x.len);
    try std.testing.expect(10 == linear.p.len);
    try std.testing.expect(1.0 == dxdt[0][0]);
    try std.testing.expect(-1.0 == dxdt[0][1]);
    try std.testing.expect(0.0 == dxdt[0][2]);
    try std.testing.expect(0.0 == dxdt[0][3]);
    try std.testing.expect(0.0 == dxdt[1][0]);
    try std.testing.expect(3.0 == dxdt[1][1]);
    try std.testing.expect(5.0 == dxdt[1][2]);
    try std.testing.expect(7.0 == dxdt[1][3]);
}
