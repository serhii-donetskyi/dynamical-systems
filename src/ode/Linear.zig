const ds = @import("../dynamical_systems.zig");
const Argument = ds.Argument;

const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn Linear(comptime v_size: u64) type {
    const ODEFactory = ds.ode.ODEFactory(v_size);
    const ODE = ds.ode.ODE(v_size);
    const vector_size = ODE.vector_size;
    return struct {
        pub const T = ODE.T;
        const arguments = [_]Argument{.{
            .name = "n",
            .value = .{ .u = 2 },
        }};

        pub const factory = ODEFactory{
            .args = &arguments,
            .vtable = &.{
                .create = factory_create,
            },
        };

        pub fn create(allocator: Allocator, n: u64) !ODE {
            const t = 0.0;

            const x_size = n;
            const x_len = if (vector_size == 0) x_size else if (x_size % vector_size > 0) x_size / vector_size + 1 else x_size / vector_size;
            const x = try allocator.alloc(T, x_len);
            errdefer allocator.free(x);

            const p_size = x_size * x_size;
            const p_len = if (vector_size == 0) p_size else if (p_size % vector_size > 0) p_size / vector_size + 1 else p_size / vector_size;
            const p = try allocator.alloc(T, p_len);
            errdefer allocator.free(p);

            const args = try allocator.alloc(Argument, 1);
            errdefer allocator.free(args);
            args[0] = .{ .name = "n", .value = .{ .u = x_size } };

            return .{
                .allocator = allocator,
                .args = args,
                .t = t,
                .x = x,
                .p = p,
                .x_dim = x_size,
                .p_dim = p_size,
                .vtable = &.{
                    .destroy = destroy,
                    .calc = calc,
                },
            };
        }

        fn factory_create(allocator: Allocator, args: []const Argument) !ODE {
            return try create(allocator, args[0].value.u);
        }

        fn destroy(self: ODE) void {
            self.allocator.free(self.x);
            self.allocator.free(self.p);
            self.allocator.free(self.args);
        }

        fn calc(self: *const ODE, t: f64, x: [*]const T, dxdt: [*]T) void {
            @setRuntimeSafety(false);
            @setFloatMode(.optimized);
            _ = t;
            if (comptime vector_size == 0) {
                for (0..self.x_dim) |i| {
                    dxdt[i] = 0;
                    for (0..self.x_dim) |j| {
                        dxdt[i] += self.p[i * self.x_dim + j] * x[j];
                    }
                }
            } else {
                for (0..self.x_dim) |i| {
                    const dxdt_s_i = i / vector_size;
                    const dxdt_v_i = i % vector_size;
                    dxdt[dxdt_s_i][dxdt_v_i] = 0;
                    for (0..self.x_dim) |j| {
                        const p_j = i * self.x_dim + j;
                        const p_s_j = p_j / vector_size;
                        const p_v_j = p_j % vector_size;
                        const x_s_j = j / vector_size;
                        const x_v_j = j % vector_size;
                        dxdt[dxdt_s_i][dxdt_v_i] += self.p[p_s_j][p_v_j] * x[x_s_j][x_v_j];
                    }
                }
            }
        }
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
    const LinearType = Linear(0);

    var linear = try LinearType.factory.create(
        std.testing.allocator,
        &[_]Argument{.{
            .name = "n",
            .value = .{ .u = n },
        }},
    );
    defer linear.destroy();
    linear.set(.{
        .t = 0.0,
        .x = &[_]f64{ 1.0, 1.0 },
        .p = &[_]f64{ 0.0, 1.0, -1.0, 0.0 },
    });

    var dxdt = [_]f64{ 0.0, 0.0 };
    linear.calc(linear.t, linear.x.ptr, &dxdt);

    try std.testing.expect(2 == linear.get_x_len());
    try std.testing.expect(4 == linear.get_p_len());
    try std.testing.expect(1.0 == dxdt[0]);
    try std.testing.expect(-1.0 == dxdt[1]);
}

test "No Vector" {
    const n = 2;
    const LinearType = Linear(0);

    var linear = try LinearType.create(std.testing.allocator, n);
    defer linear.destroy();
    linear.set(.{
        .t = 0.0,
        .x = &[_]f64{ 1.0, 1.0 },
        .p = &[_]f64{ 0.0, 1.0, -1.0, 0.0 },
    });

    var dxdt = [_]f64{ 0.0, 0.0 };
    linear.calc(linear.t, linear.x.ptr, &dxdt);

    try std.testing.expect(2 == linear.get_x_len());
    try std.testing.expect(4 == linear.get_p_len());
    try std.testing.expect(1.0 == dxdt[0]);
    try std.testing.expect(-1.0 == dxdt[1]);
}

test "Vector 1" {
    const n = 2;
    const LinearType = Linear(1);

    var linear = try LinearType.create(std.testing.allocator, n);
    defer linear.destroy();
    linear.set(.{
        .t = 0.0,
        .x = &[_]f64{ 1.0, 1.0 },
        .p = &[_]f64{ 0.0, 1.0, -1.0, 0.0 },
    });

    var dxdt = [_]LinearType.T{ .{0.0}, .{0.0} };
    linear.calc(linear.t, linear.x.ptr, &dxdt);

    try std.testing.expect(2 == linear.x.len);
    try std.testing.expect(4 == linear.p.len);
    try std.testing.expect(1.0 == dxdt[0][0]);
    try std.testing.expect(-1.0 == dxdt[1][0]);
}

test "Vector 2" {
    const n = 2;
    const LinearType = Linear(2);

    var linear = try LinearType.create(std.testing.allocator, n);
    defer linear.destroy();
    linear.set(.{
        .t = 0.0,
        .x = &[_]f64{ 1.0, 1.0 },
        .p = &[_]f64{ 0.0, 1.0, -1.0, 0.0 },
    });

    var dxdt = [_]LinearType.T{.{ 0.0, 0.0 }};
    linear.calc(linear.t, linear.x.ptr, &dxdt);

    try std.testing.expect(1 == linear.get_x_len());
    try std.testing.expect(2 == linear.get_p_len());
    try std.testing.expect(1.0 == dxdt[0][0]);
    try std.testing.expect(-1.0 == dxdt[0][1]);
}

test "Vector 4" {
    const n = 2;
    const LinearType = Linear(4);

    var linear = try LinearType.create(std.testing.allocator, n);
    defer linear.destroy();
    linear.set(.{
        .t = 0,
        .x = &[_]f64{ 1.0, 1.0 },
        .p = &[_]f64{ 0.0, 1.0, -1.0, 0.0 },
    });

    var dxdt = [_]LinearType.T{.{ 0.0, 0.0, 17.0, 19.0 }};
    linear.calc(linear.t, linear.x.ptr, &dxdt);

    try std.testing.expect(1 == linear.get_x_len());
    try std.testing.expect(1 == linear.get_p_len());
    try std.testing.expect(1.0 == dxdt[0][0]);
    try std.testing.expect(-1.0 == dxdt[0][1]);
    try std.testing.expect(17.0 == dxdt[0][2]);
    try std.testing.expect(19.0 == dxdt[0][3]);
}
