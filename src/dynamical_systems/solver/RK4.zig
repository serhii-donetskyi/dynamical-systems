const ds = @import("dynamical_systems");
const Argument = ds.Argument;
const Ode = ds.ode.Ode;
const Solver = ds.solver.Solver;

const std = @import("std");
const Allocator = std.mem.Allocator;
const RK4 = @This();

const Data = struct {
    allocator: Allocator,
    h_max: f64,
    y: []f64,
    k1: []f64,
    k2: []f64,
    k3: []f64,
    k4: []f64,
};

pub fn init(allocator: Allocator, h_max: f64) !Solver {
    const data = try allocator.create(Data);
    errdefer allocator.destroy(data);

    const y = try allocator.alloc(f64, 0);
    errdefer allocator.free(y);
    data.* = .{
        .allocator = allocator,
        .h_max = h_max,
        .y = y,
        .k1 = y[0..0],
        .k2 = y[0..0],
        .k3 = y[0..0],
        .k4 = y[0..0],
    };

    return .{
        .data = data,
        .vtable = &.{
            .deinit = deinit,
            .integrate = integrate(0),
        },
    };
}

fn deinit(self: *Solver) void {
    const data: *Data = @ptrCast(@alignCast(self.data));
    data.allocator.free(data.y);
    data.allocator.destroy(data);
}

fn integrate(comptime v_len: usize) fn (
    self: *Solver,
    ode: *const Ode,
    t: *f64,
    x: [*]f64,
    t_end: f64,
) anyerror!void {
    return struct {
        const T = if (v_len > 0) @Vector(v_len, f64) else f64;
        const C = @as(f64, 0.5);
        const A = @as(f64, 0.5);
        const B = @as(f64, 2.0);
        const D = @as(f64, 1.0 / 6.0);
        const A_vec = if (v_len > 0) @as(T, @splat(A)) else A;
        const B_vec = if (v_len > 0) @as(T, @splat(B)) else B;
        const D_vec = if (v_len > 0) @as(T, @splat(D)) else D;
        fn integrate(
            self: *Solver,
            ode: *const Ode,
            t: *f64,
            x: [*]f64,
            t_end: f64,
        ) anyerror!void {
            @setRuntimeSafety(false);
            @setFloatMode(.optimized);

            const data: *Data = @ptrCast(@alignCast(self.data));
            const x_dim = ode.getXDim();
            if (data.y.len < x_dim) {
                data.y = try data.allocator.realloc(data.y, x_dim * 5);
                data.k1 = data.y[x_dim .. x_dim * 2];
                data.k2 = data.y[x_dim * 2 .. x_dim * 3];
                data.k3 = data.y[x_dim * 3 .. x_dim * 4];
                data.k4 = data.y[x_dim * 4 .. x_dim * 5];
            }
            const sign: f64 = if (t_end > t.*) 1.0 else -1.0;
            var h = sign * data.h_max;
            var h_vec: T = if (v_len > 0) @splat(h) else h;

            for (0..1_000_000_000) |_| {
                if (sign * (t.* - t_end) >= 0)
                    break;
                if (sign * (t.* + h - t_end) >= 0) {
                    h = t_end - t.* + sign * 1e-10;
                    h_vec = if (v_len > 0) @splat(h) else h;
                }
                ode.calc(t.*, x, data.k1.ptr);
                if (comptime v_len > 0) {
                    var j = @as(usize, 0);
                    while (j + v_len <= x_dim) : (j += v_len) {
                        data.y[j..][0..v_len].* = @mulAdd(
                            T,
                            A_vec * h_vec,
                            data.k1[j..][0..v_len].*,
                            x[j..][0..v_len].*,
                        );
                    }
                    for (j..x_dim) |i| {
                        data.y[i] = x[i] + A * h * data.k1[i];
                    }
                } else {
                    for (0..x_dim) |i| {
                        data.y[i] = x[i] + A * h * data.k1[i];
                    }
                }
                ode.calc(t.* + h * C, data.y.ptr, data.k2.ptr);
                if (comptime v_len > 0) {
                    var j = @as(usize, 0);
                    while (j + v_len <= x_dim) : (j += v_len) {
                        data.y[j..][0..v_len].* = @mulAdd(
                            T,
                            A_vec * h_vec,
                            data.k2[j..][0..v_len].*,
                            x[j..][0..v_len].*,
                        );
                    }
                    for (j..x_dim) |i| {
                        data.y[i] = x[i] + A * h * data.k2[i];
                    }
                } else {
                    for (0..x_dim) |i| {
                        data.y[i] = x[i] + A * h * data.k2[i];
                    }
                }
                ode.calc(t.* + h * C, data.y.ptr, data.k3.ptr);
                if (comptime v_len > 0) {
                    var j = @as(usize, 0);
                    while (j + v_len <= x_dim) : (j += v_len) {
                        data.y[j..][0..v_len].* = @mulAdd(
                            T,
                            h_vec,
                            data.k3[j..][0..v_len].*,
                            x[j..][0..v_len].*,
                        );
                    }
                    for (j..x_dim) |i| {
                        data.y[i] = x[i] + h * data.k3[i];
                    }
                } else {
                    for (0..x_dim) |i| {
                        data.y[i] = x[i] + h * data.k3[i];
                    }
                }
                ode.calc(t.* + h, data.y.ptr, data.k4.ptr);
                if (comptime v_len > 0) {
                    var j = @as(usize, 0);
                    while (j + v_len <= x_dim) : (j += v_len) {
                        x[j..][0..v_len].* = @mulAdd(
                            T,
                            h_vec * D_vec,
                            @mulAdd(
                                T,
                                B_vec,
                                data.k2[j..][0..v_len].*,
                                data.k1[j..][0..v_len].*,
                            ) + @mulAdd(
                                T,
                                B_vec,
                                data.k3[j..][0..v_len].*,
                                data.k4[j..][0..v_len].*,
                            ),
                            x[j..][0..v_len].*,
                        );
                    }
                    for (j..x_dim) |i| {
                        x[i] += (data.k1[i] + B * data.k2[i] + B * data.k3[i] + data.k4[i]) * h * D;
                    }
                } else {
                    for (0..x_dim) |i| {
                        x[i] += (data.k1[i] + B * data.k2[i] + B * data.k3[i] + data.k4[i]) * h * D;
                    }
                }
                t.* += h;
            }
        }
    }.integrate;
}

pub const Factory = struct {
    fn init(allocator: Allocator, args: []const Argument) !Solver {
        const h_max = args[0].value.f;
        return try RK4.init(allocator, h_max);
    }
    fn getArguments() []const Argument {
        return &[_]Argument{.{
            .name = "h_max",
            .value = .{ .f = 0.01 },
        }};
    }
    fn factory() Solver.Factory {
        return .{
            .vtable = &.{
                .init = Factory.init,
                .getArguments = getArguments,
            },
        };
    }
};

export const factory = &Factory.factory();

test "factory" {
    var solver = try factory.init(
        std.testing.allocator,
        factory.getArguments(),
    );
    defer solver.deinit();

    for ([_]usize{ 2, 4, 1 }) |n| {
        var ode = try ds.ode.Constant.init(std.testing.allocator, n);
        defer ode.deinit();

        var t = ode.getT();
        const x = try std.testing.allocator.alloc(f64, n);
        defer std.testing.allocator.free(x);

        for (0..n) |i| {
            x[i] = ode.getX(i);
        }
        try solver.integrate(&ode, &t, x.ptr, t + 0.1);
    }
}
