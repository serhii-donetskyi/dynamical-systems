const ds = @import("../dynamical_systems.zig");
const Argument = ds.Argument;
const ODE = ds.ode.ODE;
const Solver = ds.solver.Solver;
const Factory = ds.solver.Solver.Factory;

const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn RK4(comptime v_len: usize) type {
    return struct {
        const T = if (v_len > 0) @Vector(v_len, f64) else f64;
        const C = @as(f64, 0.5);
        const A = @as(f64, 0.5);
        const B = @as(f64, 2.0);
        const D = @as(f64, 1.0 / 6.0);
        const A_vec = if (v_len > 0) @as(T, @splat(A)) else A;
        const B_vec = if (v_len > 0) @as(T, @splat(B)) else B;
        const D_vec = if (v_len > 0) @as(T, @splat(D)) else D;

        const Data = struct {
            capacity: usize,
            buffer: []f64,
            y: []f64,
            k1: []f64,
            k2: []f64,
            k3: []f64,
            k4: []f64,

            fn alloc(allocator: Allocator, n: usize) !Data {
                const buffer = try allocator.alloc(f64, n * 5);

                return .{
                    .capacity = n,
                    .buffer = buffer,
                    .y = buffer[0..n],
                    .k1 = buffer[n .. 2 * n],
                    .k2 = buffer[2 * n .. 3 * n],
                    .k3 = buffer[3 * n .. 4 * n],
                    .k4 = buffer[4 * n .. 5 * n],
                };
            }

            fn resize(self: *Data, allocator: Allocator, n: usize) !void {
                self.free(allocator);
                const buffer = try allocator.alloc(f64, n * 5);
                errdefer allocator.free(buffer);
                self.buffer = buffer;
                self.y = buffer[0..n];
                self.k1 = buffer[n .. 2 * n];
                self.k2 = buffer[2 * n .. 3 * n];
                self.k3 = buffer[3 * n .. 4 * n];
                self.k4 = buffer[4 * n .. 5 * n];
            }

            fn free(self: *Data, allocator: Allocator) void {
                allocator.free(self.buffer);
                self.capacity = 0;
            }
        };

        pub fn init(allocator: Allocator, h_max: f64) !Solver {
            const args = try allocator.alloc(Argument, 1);
            errdefer allocator.free(args);
            args[0] = .{ .name = "h_max", .value = .{ .f = h_max } };

            const dim = 8;
            const data = try allocator.create(Data);
            errdefer allocator.destroy(data);
            data.* = try Data.alloc(allocator, dim);
            errdefer data.free(allocator);

            return .{
                .allocator = allocator,
                .args = args,
                .dim = dim,
                .data = data,
                .vtable = &.{
                    .deinit = deinit,
                    .integrate = integrate,
                },
            };
        }
        fn deinit(self: *Solver) void {
            const data: *Data = @ptrCast(@alignCast(self.data));
            data.free(self.allocator);
            self.allocator.destroy(data);
            self.allocator.free(self.args);
        }
        fn integrate(
            self: *Solver,
            ode: *const ODE,
            t: *f64,
            x: [*]f64,
            t_end: f64,
        ) !void {
            @setRuntimeSafety(false);
            @setFloatMode(.optimized);
            try resize(self, ode);
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
        fn resize(self: *Solver, ode: *const ODE) !void {
            if (self.dim == ode.getXDim())
                return;
            self.dim = ode.getXDim();
            const data: *Data = @ptrCast(@alignCast(self.data));
            if (data.capacity < self.dim) {
                try data.resize(self.allocator, self.dim);
                errdefer data.free(self.allocator);
            }
            inline for ([_]usize{ 32, 16, 8, 4, 2, 0 }) |vector_len| {
                if (vector_len >= self.dim) {
                    var rk4 = try RK4(vector_len).init(
                        self.allocator,
                        self.args[0].value.f,
                    );
                    defer rk4.deinit();
                    self.vtable = rk4.vtable;
                    return;
                }
            }
        }
    };
}

fn create(allocator: Allocator, args: []const Argument) !Solver {
    const h_max = args[0].value.f;
    inline for ([_]usize{ 32, 16, 8, 4, 2 }) |v_len| {
        if (h_max >= v_len)
            return try RK4(v_len).init(allocator, h_max);
    }
    return try RK4(0).init(allocator, h_max);
}
fn getArguments() []const Argument {
    const arguments = comptime [_]Argument{.{
        .name = "h_max",
        .value = .{ .f = 0.01 },
    }};
    return &arguments;
}
pub const factory = Factory{
    .vtable = &.{
        .create = create,
        .getArguments = getArguments,
    },
};

test "Factory" {
    var rk4 = try factory.create(
        std.testing.allocator,
        factory.getArguments(),
    );
    defer factory.destroy(rk4);

    for ([_]usize{ 8, 16 }) |n| {
        var linear = try ds.ode.Linear(0).init(std.testing.allocator, n);
        defer linear.deinit();
        try rk4.integrate(&linear, &linear.t, linear.x.ptr, linear.t + 0.1);
    }
}
