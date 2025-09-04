//! By convention, root.zig is the root source file when making a library.
const std = @import("std");
const builtin = @import("builtin");

pub const Argument = @import("Argument.zig");
pub const ode = @import("ode/ode.zig");
pub const solver = @import("solver/solver.zig");

test {
    _ = Argument;
    _ = ode;
    _ = solver;
}

const h = 0.01;
const n = 3;
const VecT = @Vector(n, f64);
const ArrT = [n]f64;

fn calc(noalias x: anytype, noalias dxdt: anytype) void {
    dxdt[0] = 21 * x[0] - 47 * x[1] + 22 * x[2];
    dxdt[1] = 60 * x[0] - 127 * x[1] + 58 * x[2];
    dxdt[2] = 129 * x[0] - 245 * x[1] + 106 * x[2];
}

test "vector performance" {
    const T = VecT;
    var x: T = .{ 1, 0, 0 };
    var y: T = undefined;
    var k1: T = undefined;
    var k2: T = undefined;
    var k3: T = undefined;
    var k4: T = undefined;

    const two_vec = @as(T, @splat(2));
    const h_vec = @as(T, @splat(h));
    const h_2_vec = @as(T, @splat(h * 0.5));
    const h_6_vec = @as(T, @splat(h / 6.0));

    const start = std.time.milliTimestamp();
    for (0..10000000) |_| {
        calc(&x, &k1);
        y = x + h_2_vec * k1;
        calc(&y, &k2);
        y = x + h_2_vec * k2;
        calc(&y, &k3);
        y = x + h_vec * k3;
        calc(&y, &k4);
        x += h_6_vec * (k1 + two_vec * k2 + two_vec * k3 + k4);
    }
    const end = std.time.milliTimestamp();
    std.debug.print("Vector result: {any}\n", .{x});
    std.debug.print("Vector performance: {d}ms\n", .{end - start});
}

test "array performance" {
    const start = std.time.milliTimestamp();
    const T = ArrT;
    var x: T = .{ 1, 0, 0 };
    var y: T = undefined;
    var k1: T = undefined;
    var k2: T = undefined;
    var k3: T = undefined;
    var k4: T = undefined;

    for (0..10000000) |_| {
        calc(&x, &k1);
        for (0..n) |i| {
            y[i] = x[i] + k1[i] * h * 0.5;
        }
        calc(&y, &k2);
        for (0..n) |i| {
            y[i] = x[i] + k2[i] * h * 0.5;
        }
        calc(&y, &k3);
        for (0..n) |i| {
            y[i] = x[i] + k3[i] * h;
        }
        calc(&y, &k4);
        for (0..n) |i| {
            x[i] += (k1[i] + 2 * k2[i] + 2 * k3[i] + k4[i]) * h / 6.0;
        }
    }
    const end = std.time.milliTimestamp();
    std.debug.print("Array result: {any}\n", .{x});
    std.debug.print("Array performance: {d}ms\n", .{end - start});
}
