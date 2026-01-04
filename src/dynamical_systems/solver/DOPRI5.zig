const ds = @import("dynamical_systems");
const std = @import("std");
const builtin = @import("builtin");

const Argument = ds.Argument;
const Ode = ds.ode.Ode;
const Solver = ds.solver.Solver;

const Allocator = std.mem.Allocator;
const DOPRI5 = @This();

const Data = struct {
    allocator: Allocator,
    h_max: f64,
    eps: f64,
    dim: usize,
    buffer: []f64,
};

pub fn init(allocator: Allocator, h_max: f64, eps: f64) !Solver {
    const data = try allocator.create(Data);
    errdefer allocator.destroy(data);

    const buffer = try allocator.alloc(f64, 0);
    errdefer allocator.free(buffer);
    data.* = .{
        .allocator = allocator,
        .h_max = h_max,
        .eps = eps,
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
        const C2 = (2.0 / 10.0);
        const C3 = (3.0 / 10.0);
        const C4 = (8.0 / 10.0);
        const C5 = (8.0 / 9.0);

        const A21 = (2.0 / 10.0);

        const A31 = (3.0 / 40.0);
        const A32 = (9.0 / 40.0);

        const A41 = (44.0 / 45.0);
        const A42 = (-56.0 / 15.0);
        const A43 = (32.0 / 9.0);

        const A51 = (19372.0 / 6561.0);
        const A52 = (-25360.0 / 2187.0);
        const A53 = (64448.0 / 6561.0);
        const A54 = (-212.0 / 729.0);

        const A61 = (9017.0 / 3168.0);
        const A62 = (-355.0 / 33.0);
        const A63 = (46732.0 / 5247.0);
        const A64 = (49.0 / 176.0);
        const A65 = (-5103.0 / 18656.0);

        const A71 = (35.0 / 384.0);
        const A73 = (500.0 / 1113.0);
        const A74 = (125.0 / 192.0);
        const A75 = (-2187.0 / 6784.0);
        const A76 = (11.0 / 84.0);

        const E1 = (71.0 / 57600.0);
        const E3 = (-71.0 / 16695.0);
        const E4 = (71.0 / 1920.0);
        const E5 = (-17253.0 / 339200.0);
        const E6 = (22.0 / 525.0);
        const E7 = (-1.0 / 40.0);

        const V = if (v_len > 0) @Vector(v_len, f64) else void;

        const A21_vec = if (v_len > 0) @as(V, @splat(A21)) else {};
        const A31_vec = if (v_len > 0) @as(V, @splat(A31)) else {};
        const A32_vec = if (v_len > 0) @as(V, @splat(A32)) else {};
        const A41_vec = if (v_len > 0) @as(V, @splat(A41)) else {};
        const A42_vec = if (v_len > 0) @as(V, @splat(A42)) else {};
        const A43_vec = if (v_len > 0) @as(V, @splat(A43)) else {};
        const A51_vec = if (v_len > 0) @as(V, @splat(A51)) else {};
        const A52_vec = if (v_len > 0) @as(V, @splat(A52)) else {};
        const A53_vec = if (v_len > 0) @as(V, @splat(A53)) else {};
        const A54_vec = if (v_len > 0) @as(V, @splat(A54)) else {};
        const A61_vec = if (v_len > 0) @as(V, @splat(A61)) else {};
        const A62_vec = if (v_len > 0) @as(V, @splat(A62)) else {};
        const A63_vec = if (v_len > 0) @as(V, @splat(A63)) else {};
        const A64_vec = if (v_len > 0) @as(V, @splat(A64)) else {};
        const A65_vec = if (v_len > 0) @as(V, @splat(A65)) else {};
        const A71_vec = if (v_len > 0) @as(V, @splat(A71)) else {};
        const A73_vec = if (v_len > 0) @as(V, @splat(A73)) else {};
        const A74_vec = if (v_len > 0) @as(V, @splat(A74)) else {};
        const A75_vec = if (v_len > 0) @as(V, @splat(A75)) else {};
        const A76_vec = if (v_len > 0) @as(V, @splat(A76)) else {};
        const E1_vec = if (v_len > 0) @as(V, @splat(E1)) else {};
        const E3_vec = if (v_len > 0) @as(V, @splat(E3)) else {};
        const E4_vec = if (v_len > 0) @as(V, @splat(E4)) else {};
        const E5_vec = if (v_len > 0) @as(V, @splat(E5)) else {};
        const E6_vec = if (v_len > 0) @as(V, @splat(E6)) else {};
        const E7_vec = if (v_len > 0) @as(V, @splat(E7)) else {};
        const rtol_vec = if (v_len > 0) @as(V, @splat(1e-5)) else {};

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
            if (x_dim != data.dim) { // check if we are using the correct integration function
                if (data.buffer.len < x_dim * 7) { // check if we have enough buffer
                    data.buffer = try data.allocator.realloc(data.buffer, x_dim * 7);
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
            const k5 = k4 + x_dim;
            const k6 = k5 + x_dim;

            const sign: f64 = if (t_end > t.*) 1.0 else -1.0;
            var h = sign * data.h_max;
            var h_vec: V = if (v_len > 0) @splat(h) else {};
            var reject = false;

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
                    var j: usize = 0;
                    while (j + v_len <= x_dim) : (j += v_len) {
                        y[j..][0..v_len].* = @mulAdd(
                            V,
                            h_vec,
                            A21_vec * k1[j..][0..v_len].*,
                            x[j..][0..v_len].*,
                        );
                    }
                    for (j..x_dim) |i| {
                        y[i] = x[i] + h * A21 * k1[i];
                    }
                } else {
                    for (0..x_dim) |i| {
                        y[i] = x[i] + h * A21 * k1[i];
                    }
                }
                ode.calc(t.* + h * C2, y, k2);

                // stage 3
                if (comptime v_len > 0) {
                    var j: usize = 0;
                    while (j + v_len <= x_dim) : (j += v_len) {
                        y[j..][0..v_len].* = @mulAdd(
                            V,
                            h_vec,
                            A32_vec * k2[j..][0..v_len].* + A31_vec * k1[j..][0..v_len].*,
                            x[j..][0..v_len].*,
                        );
                    }
                    for (j..x_dim) |i| {
                        y[i] = x[i] + h * (A31 * k1[i] + A32 * k2[i]);
                    }
                } else {
                    for (0..x_dim) |i| {
                        y[i] = x[i] + h * (A31 * k1[i] + A32 * k2[i]);
                    }
                }
                ode.calc(t.* + h * C3, y, k3);

                // stage 4
                if (comptime v_len > 0) {
                    var j: usize = 0;
                    while (j + v_len <= x_dim) : (j += v_len) {
                        y[j..][0..v_len].* = @mulAdd(
                            V,
                            h_vec,
                            A41_vec * k1[j..][0..v_len].* + A42_vec * k2[j..][0..v_len].* + A43_vec * k3[j..][0..v_len].*,
                            x[j..][0..v_len].*,
                        );
                    }
                    for (j..x_dim) |i| {
                        y[i] = x[i] + h * (A41 * k1[i] + A42 * k2[i] + A43 * k3[i]);
                    }
                } else {
                    for (0..x_dim) |i| {
                        y[i] = x[i] + h * (A41 * k1[i] + A42 * k2[i] + A43 * k3[i]);
                    }
                }
                ode.calc(t.* + h * C4, y, k4);

                // stage 5
                if (comptime v_len > 0) {
                    var j: usize = 0;
                    while (j + v_len <= x_dim) : (j += v_len) {
                        y[j..][0..v_len].* = @mulAdd(
                            V,
                            h_vec,
                            A51_vec * k1[j..][0..v_len].* + A52_vec * k2[j..][0..v_len].* + A53_vec * k3[j..][0..v_len].* + A54_vec * k4[j..][0..v_len].*,
                            x[j..][0..v_len].*,
                        );
                    }
                    for (j..x_dim) |i| {
                        y[i] = x[i] + h * (A51 * k1[i] + A52 * k2[i] + A53 * k3[i] + A54 * k4[i]);
                    }
                } else {
                    for (0..x_dim) |i| {
                        y[i] = x[i] + h * (A51 * k1[i] + A52 * k2[i] + A53 * k3[i] + A54 * k4[i]);
                    }
                }
                ode.calc(t.* + h * C5, y, k5);

                // stage 6
                const tph = t.* + h;
                if (comptime v_len > 0) {
                    var j: usize = 0;
                    while (j + v_len <= x_dim) : (j += v_len) {
                        y[j..][0..v_len].* = @mulAdd(
                            V,
                            h_vec,
                            A61_vec * k1[j..][0..v_len].* + A62_vec * k2[j..][0..v_len].* + A63_vec * k3[j..][0..v_len].* + A64_vec * k4[j..][0..v_len].* + A65_vec * k5[j..][0..v_len].*,
                            x[j..][0..v_len].*,
                        );
                    }
                    for (j..x_dim) |i| {
                        y[i] = x[i] + h * (A61 * k1[i] + A62 * k2[i] + A63 * k3[i] + A64 * k4[i] + A65 * k5[i]);
                    }
                } else {
                    for (0..x_dim) |i| {
                        y[i] = x[i] + h * (A61 * k1[i] + A62 * k2[i] + A63 * k3[i] + A64 * k4[i] + A65 * k5[i]);
                    }
                }
                ode.calc(tph, y, k6);

                // stage 7
                if (comptime v_len > 0) {
                    var j: usize = 0;
                    while (j + v_len <= x_dim) : (j += v_len) {
                        y[j..][0..v_len].* = @mulAdd(
                            V,
                            h_vec,
                            A71_vec * k1[j..][0..v_len].* + A73_vec * k3[j..][0..v_len].* + A74_vec * k4[j..][0..v_len].* + A75_vec * k5[j..][0..v_len].* + A76_vec * k6[j..][0..v_len].*,
                            x[j..][0..v_len].*,
                        );
                    }
                    for (j..x_dim) |i| {
                        y[i] = x[i] + h * (A71 * k1[i] + A73 * k3[i] + A74 * k4[i] + A75 * k5[i] + A76 * k6[i]);
                    }
                } else {
                    for (0..x_dim) |i| {
                        y[i] = x[i] + h * (A71 * k1[i] + A73 * k3[i] + A74 * k4[i] + A75 * k5[i] + A76 * k6[i]);
                    }
                }
                ode.calc(tph, y, k2);

                // error estimation
                var err: f64 = 0.0;
                if (comptime v_len > 0) {
                    var err_vec: V = @splat(0.0);
                    var j: usize = 0;
                    while (j + v_len <= x_dim) : (j += v_len) {
                        var rerr_vec: V = h_vec * (E1_vec * k1[j..][0..v_len].* + E3_vec * k3[j..][0..v_len].* + E4_vec * k4[j..][0..v_len].* + E5_vec * k5[j..][0..v_len].* + E6_vec * k6[j..][0..v_len].* + E7_vec * k2[j..][0..v_len].*);
                        rerr_vec /= @max(rtol_vec, @abs(@as(V, y[j..][0..v_len].*)), @abs(@as(V, x[j..][0..v_len].*)));
                        err_vec += rerr_vec * rerr_vec;
                    }
                    err = @reduce(.Add, err_vec);
                    for (j..x_dim) |i| {
                        k4[i] = h * (E1 * k1[i] + E3 * k3[i] + E4 * k4[i] + E5 * k5[i] + E6 * k6[i] + E7 * k2[i]);

                        const rerr = k4[i] / @max(1e-5, @abs(y[i]), @abs(x[i]));
                        err += rerr * rerr;
                    }
                } else {
                    for (0..x_dim) |i| {
                        k4[i] = h * (E1 * k1[i] + E3 * k3[i] + E4 * k4[i] + E5 * k5[i] + E6 * k6[i] + E7 * k2[i]);

                        const rerr = k4[i] / @max(1e-5, @abs(y[i]), @abs(x[i]));
                        err += rerr * rerr;
                    }
                }
                err = @sqrt(err / @as(f64, @floatFromInt(x_dim)));
                const fac = std.math.clamp(
                    std.math.pow(f64, err / data.eps, 0.2),
                    0.2,
                    5.0,
                );
                var h_new = h / fac;
                if (err < data.eps) {
                    // step accepted
                    t.* = tph;
                    for (0..x_dim) |i| {
                        x[i] = y[i];
                    }
                    if (@abs(h_new) > data.h_max)
                        h_new = sign * data.h_max;
                    if (reject) {
                        h_new = @min(@abs(h), @abs(h_new)) * sign;
                        reject = false;
                    }
                } else {
                    // step rejected
                    if (h_new != h_new) // h_new is NaN
                        h_new = 0.6 * h;
                    h_new = @min(@abs(h_new), @abs(h)) * sign;
                    if (reject)
                        h_new *= 0.9
                    else
                        reject = true;
                }
                h = h_new;
                if (comptime v_len > 0) h_vec = @splat(h_new);
            }
        }
    }._integrate;
}

pub const Factory = struct {
    fn init(allocator: Allocator, args: []const Argument) !Solver {
        return try DOPRI5.init(allocator, args[0].value.f, args[1].value.f);
    }
    fn getArguments() []const Argument {
        return &[_]Argument{
            .{ .name = "h_max", .value = .{ .f = 0.01 }, .description = "The maximum step size" },
            .{ .name = "eps", .value = .{ .f = 1e-5 }, .description = "The error tolerance" },
        };
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

test "DOPRI5" {
    const allocator = std.testing.allocator;
    var solver = try factory.init(allocator, factory.getArguments());
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
