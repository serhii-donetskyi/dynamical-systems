const ds = @import("../dynamical_systems.zig");
const Argument = ds.Argument;
const ODE = ds.ode.ODE;
const Solver = ds.solver.Solver;

const std = @import("std");
const Allocator = std.mem.Allocator;
const RK4 = @This();

const Data = struct {
    allocator: Allocator,
    capacity: usize,
    buffer: []f64,
    y: []f64,
    k1: []f64,
    k2: []f64,
    k3: []f64,
    k4: []f64,

    pub fn init(allocator: Allocator) !Data {
        return .{
            .allocator = allocator,
            .capacity = 0,
            .buffer = try allocator.alloc(f64, 0),
            .y = undefined,
            .k1 = undefined,
            .k2 = undefined,
            .k3 = undefined,
            .k4 = undefined,
        };
    }
    pub fn ensureCapacity(self: *Data, n: usize) !void {
        if (n <= self.capacity)
            return;
        self.buffer = try self.allocator.realloc(self.buffer, n * 5);
        self.capacity = n;
        self.y = self.buffer[0..n];
        self.k1 = self.buffer[n .. n * 2];
        self.k2 = self.buffer[n * 2 .. n * 3];
        self.k3 = self.buffer[n * 3 .. n * 4];
        self.k4 = self.buffer[n * 4 .. n * 5];
    }
    pub fn deinit(self: *Data) void {
        if (self.capacity == 0)
            return;
        self.allocator.free(self.buffer);
        self.capacity = 0;
    }
};

pub fn init(allocator: Allocator, h_max: f64) !Solver {
    const args = try allocator.alloc(Argument, 1);
    errdefer allocator.free(args);
    args[0] = .{ .name = "h_max", .value = .{ .f = h_max } };

    const data = try allocator.create(Data);
    errdefer allocator.destroy(data);
    data.* = try Data.init(allocator);
    errdefer data.deinit();

    return .{
        .allocator = allocator,
        .args = args,
        .dim = 0,
        .data = data,
        .vtable = &.{
            .deinit = deinit,
            .integrate = integrate(0),
        },
    };
}
fn deinit(self: *Solver) void {
    const data: *Data = @ptrCast(@alignCast(self.data));
    data.deinit();
    self.allocator.free(self.args);
    self.allocator.destroy(data);
}
fn integrate(comptime v_len: usize) fn (
    self: *Solver,
    ode: *const ODE,
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
            ode: *const ODE,
            t: *f64,
            x: [*]f64,
            t_end: f64,
        ) anyerror!void {
            @setRuntimeSafety(false);
            @setFloatMode(.optimized);
            try adjust(self, ode);
            const data: *Data = @ptrCast(@alignCast(self.data));
            const sign: f64 = if (t_end > t.*) 1.0 else -1.0;
            var h = sign * self.args[0].value.f;
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
                    while (j + v_len <= self.dim) : (j += v_len) {
                        data.y[j..][0..v_len].* = @mulAdd(
                            T,
                            A_vec * h_vec,
                            data.k1[j..][0..v_len].*,
                            x[j..][0..v_len].*,
                        );
                    }
                    for (j..self.dim) |i| {
                        data.y[i] = x[i] + A * h * data.k1[i];
                    }
                } else {
                    for (0..self.dim) |i| {
                        data.y[i] = x[i] + A * h * data.k1[i];
                    }
                }
                ode.calc(t.* + h * C, data.y.ptr, data.k2.ptr);
                if (comptime v_len > 0) {
                    var j = @as(usize, 0);
                    while (j + v_len <= self.dim) : (j += v_len) {
                        data.y[j..][0..v_len].* = @mulAdd(
                            T,
                            A_vec * h_vec,
                            data.k2[j..][0..v_len].*,
                            x[j..][0..v_len].*,
                        );
                    }
                    for (j..self.dim) |i| {
                        data.y[i] = x[i] + A * h * data.k2[i];
                    }
                } else {
                    for (0..self.dim) |i| {
                        data.y[i] = x[i] + A * h * data.k2[i];
                    }
                }
                ode.calc(t.* + h * C, data.y.ptr, data.k3.ptr);
                if (comptime v_len > 0) {
                    var j = @as(usize, 0);
                    while (j + v_len <= self.dim) : (j += v_len) {
                        data.y[j..][0..v_len].* = @mulAdd(
                            T,
                            h_vec,
                            data.k3[j..][0..v_len].*,
                            x[j..][0..v_len].*,
                        );
                    }
                    for (j..self.dim) |i| {
                        data.y[i] = x[i] + h * data.k3[i];
                    }
                } else {
                    for (0..self.dim) |i| {
                        data.y[i] = x[i] + h * data.k3[i];
                    }
                }
                ode.calc(t.* + h, data.y.ptr, data.k4.ptr);
                if (comptime v_len > 0) {
                    var j = @as(usize, 0);
                    while (j + v_len <= self.dim) : (j += v_len) {
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
                    for (j..self.dim) |i| {
                        x[i] += (data.k1[i] + B * data.k2[i] + B * data.k3[i] + data.k4[i]) * h * D;
                    }
                } else {
                    for (0..self.dim) |i| {
                        x[i] += (data.k1[i] + B * data.k2[i] + B * data.k3[i] + data.k4[i]) * h * D;
                    }
                }
                t.* += h;
            }
        }
    }.integrate;
}
fn adjust(self: *Solver, ode: *const ODE) !void {
    if (self.dim == ode.getXDim())
        return;
    self.dim = ode.getXDim();
    const data: *Data = @ptrCast(@alignCast(self.data));
    try data.ensureCapacity(self.dim);
    inline for ([_]usize{ 32, 16, 8, 4, 2, 0 }) |v_len| {
        if (self.dim >= v_len) {
            self.vtable = &.{
                .deinit = deinit,
                .integrate = integrate(v_len),
            };
            return;
        }
    }
}

const Factory = struct {
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
pub const factory = Factory.factory();

test "factory" {
    var solver = try factory.init(
        std.testing.allocator,
        factory.getArguments(),
    );
    defer solver.deinit();

    for ([_]usize{ 2, 4, 1 }) |n| {
        var ode = try ds.ode.Linear.init(std.testing.allocator, n);
        defer ode.deinit();

        var t = ode.t;
        const x = ode.x;
        try solver.integrate(&ode, &t, x.ptr, t + 0.1);
    }
}
