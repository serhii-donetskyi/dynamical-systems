const ds = @import("dynamical_systems");
const std = @import("std");
const builtin = @import("builtin");

const Argument = ds.Argument;
const Ode = ds.ode.Ode;
const Solver = ds.solver.Solver;

const Allocator = std.mem.Allocator;
const RK4 = @This();

const Data = struct {
    allocator: Allocator,
    h_max: f64,
    dim: usize,
    buffer: []f64,
};

pub fn init(allocator: Allocator, h_max: f64) !Solver {
    const data = try allocator.create(Data);
    errdefer allocator.destroy(data);

    const buffer = try allocator.alloc(f64, 0);
    errdefer allocator.free(buffer);
    data.* = .{
        .allocator = allocator,
        .h_max = h_max,
        .dim = 0,
        .buffer = buffer,
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
    data.allocator.free(data.buffer);
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
        const V = if (v_len > 0) @Vector(v_len, f64) else void;
        const C = @as(f64, 0.5);
        const A = @as(f64, 0.5);
        const B = @as(f64, 2.0);
        const D = @as(f64, 1.0 / 6.0);
        const A_vec = if (v_len > 0) @as(V, @splat(A)) else {};
        const B_vec = if (v_len > 0) @as(V, @splat(B)) else {};
        const D_vec = if (v_len > 0) @as(V, @splat(D)) else {};
        fn _integrate(
            self: *Solver,
            ode: *const Ode,
            t: *f64,
            x: [*]f64,
            t_end: f64,
        ) anyerror!void {
            if (comptime builtin.mode != .Debug) {
                @setRuntimeSafety(false);
                @setFloatMode(.optimized);
            }

            const data: *Data = @ptrCast(@alignCast(self.data));
            const x_dim = ode.getXDim();
            if (x_dim != data.dim) {
                if (data.buffer.len < x_dim * 5) {
                    data.buffer = try data.allocator.realloc(data.buffer, x_dim * 5);
                }
                data.dim = x_dim; // make sure check passes next time we call this function
                inline for ([_]usize{ 32, 16, 8, 4, 2, 0 }) |v_len_| {
                    if (x_dim >= 2 * v_len_) { // pick an integration function
                        self.vtable = &.{
                            .deinit = deinit,
                            .integrate = integrate(v_len_),
                        };
                        return self.integrate(ode, t, x, t_end);
                    }
                }
                unreachable;
            }
            const y = data.buffer.ptr;
            const k1 = y + x_dim;
            const k2 = k1 + x_dim;
            const k3 = k2 + x_dim;
            const k4 = k3 + x_dim;

            const sign: f64 = if (t_end > t.*) 1.0 else -1.0;
            var h = sign * data.h_max;
            var h_vec: V = if (v_len > 0) @splat(h) else {};

            for (0..1_000_000_000) |_| {
                if (sign * (t.* - t_end) >= 0)
                    break;
                if (sign * (t.* + h - t_end) >= 0) {
                    h = t_end - t.* + sign * 1e-10;
                    if (comptime v_len > 0) h_vec = @splat(h);
                }

                // stage 1
                ode.calc(t.*, x, k1);

                // stage 2
                if (comptime v_len > 0) {
                    var j = @as(usize, 0);
                    while (j + v_len <= x_dim) : (j += v_len) {
                        y[j..][0..v_len].* = @mulAdd(
                            V,
                            A_vec * h_vec,
                            k1[j..][0..v_len].*,
                            x[j..][0..v_len].*,
                        );
                    }
                    for (j..x_dim) |i| {
                        y[i] = x[i] + A * h * k1[i];
                    }
                } else {
                    for (0..x_dim) |i| {
                        y[i] = x[i] + A * h * k1[i];
                    }
                }
                ode.calc(t.* + h * C, y, k2);

                // stage 3
                if (comptime v_len > 0) {
                    var j = @as(usize, 0);
                    while (j + v_len <= x_dim) : (j += v_len) {
                        y[j..][0..v_len].* = @mulAdd(
                            V,
                            A_vec * h_vec,
                            k2[j..][0..v_len].*,
                            x[j..][0..v_len].*,
                        );
                    }
                    for (j..x_dim) |i| {
                        y[i] = x[i] + A * h * k2[i];
                    }
                } else {
                    for (0..x_dim) |i| {
                        y[i] = x[i] + A * h * k2[i];
                    }
                }
                ode.calc(t.* + h * C, y, k3);

                // stage 4
                if (comptime v_len > 0) {
                    var j = @as(usize, 0);
                    while (j + v_len <= x_dim) : (j += v_len) {
                        y[j..][0..v_len].* = @mulAdd(
                            V,
                            h_vec,
                            k3[j..][0..v_len].*,
                            x[j..][0..v_len].*,
                        );
                    }
                    for (j..x_dim) |i| {
                        y[i] = x[i] + h * k3[i];
                    }
                } else {
                    for (0..x_dim) |i| {
                        y[i] = x[i] + h * k3[i];
                    }
                }
                ode.calc(t.* + h, y, k4);

                // update x
                if (comptime v_len > 0) {
                    var j = @as(usize, 0);
                    while (j + v_len <= x_dim) : (j += v_len) {
                        x[j..][0..v_len].* = @mulAdd(
                            V,
                            h_vec * D_vec,
                            @mulAdd(
                                V,
                                B_vec,
                                k2[j..][0..v_len].*,
                                k1[j..][0..v_len].*,
                            ) + @mulAdd(
                                V,
                                B_vec,
                                k3[j..][0..v_len].*,
                                k4[j..][0..v_len].*,
                            ),
                            x[j..][0..v_len].*,
                        );
                    }
                    for (j..x_dim) |i| {
                        x[i] += (k1[i] + B * k2[i] + B * k3[i] + k4[i]) * h * D;
                    }
                } else {
                    for (0..x_dim) |i| {
                        x[i] += (k1[i] + B * k2[i] + B * k3[i] + k4[i]) * h * D;
                    }
                }
                t.* += h;
            }
        }
    }._integrate;
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
