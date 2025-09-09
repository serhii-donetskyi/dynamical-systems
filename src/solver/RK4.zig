const ds = @import("../dynamical_systems.zig");
const Argument = ds.Argument;

const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn RK4(comptime vector_size: u64) type {
    const ODE = ds.ode.ODE(vector_size);
    const Solver = ds.solver.Solver(vector_size);
    const SolverFactory = ds.solver.SolverFactory(vector_size);
    const is_vec = comptime vector_size > 0;

    return struct {
        pub const T = ODE.T;
        const C: f64 = 0.5;
        const A: T = if (is_vec) @splat(0.5) else 0.5;
        const B: T = if (is_vec) @splat(2.0) else 2.0;
        const D: T = if (is_vec) @splat(1.0 / 6.0) else 1.0 / 6.0;

        const Data = struct {
            capacity: u64,
            buffer: []T,
            y: []T,
            k1: []T,
            k2: []T,
            k3: []T,
            k4: []T,

            fn alloc(allocator: Allocator, n: u64) !Data {
                const buffer = try allocator.alloc(T, n * 5);

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

            fn resize(self: *Data, allocator: Allocator, n: u64) !void {
                self.free(allocator);
                const buffer = try allocator.alloc(T, n * 5);
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

            const capacity = 8;
            const data = try allocator.create(Data);
            errdefer allocator.destroy(data);
            data.* = try Data.alloc(allocator, capacity);
            errdefer data.free(allocator);

            return .{
                .allocator = allocator,
                .args = args,
                .dim = capacity,
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
            x: [*]T,
            t_end: f64,
        ) !void {
            @setRuntimeSafety(false);
            @setFloatMode(.optimized);
            const data: *Data = @ptrCast(@alignCast(self.data));
            self.dim = ode.x.len;
            if (data.capacity < self.dim) {
                try data.resize(self.allocator, self.dim);
                errdefer data.free(self.allocator);
            }
            const sign: f64 = if (t_end > t.*) 1.0 else -1.0;
            var h = sign * self.args[0].value.f;
            var h_vec: T = if (is_vec) @splat(h) else h;

            for (0..1_000_000_000) |_| {
                if (sign * (t.* - t_end) >= 0)
                    break;
                if (sign * (t.* + h - t_end) >= 0) {
                    h = t_end - t.* + sign * 1e-10;
                    h_vec = if (is_vec) @splat(h) else h;
                }
                ode.calc(t.*, x, data.k1.ptr);
                for (0..self.dim) |i| {
                    data.y[i] = x[i] + A * h_vec * data.k1[i];
                }
                ode.calc(t.* + h * C, data.y.ptr, data.k2.ptr);
                for (0..self.dim) |i| {
                    data.y[i] = x[i] + A * h_vec * data.k2[i];
                }
                ode.calc(t.* + h * C, data.y.ptr, data.k3.ptr);
                for (0..self.dim) |i| {
                    data.y[i] = x[i] + h_vec * data.k3[i];
                }
                ode.calc(t.* + h, data.y.ptr, data.k4.ptr);
                for (0..self.dim) |i| {
                    x[i] += (data.k1[i] + B * data.k2[i] + B * data.k3[i] + data.k4[i]) * h_vec * D;
                }
                t.* += h;
            }
        }

        const arguments = [_]Argument{.{
            .name = "h_max",
            .value = .{ .f = 0.01 },
        }};
        fn create(allocator: Allocator, args: []const Argument) !Solver {
            return try init(allocator, args[0].value.f);
        }
        pub const factory = SolverFactory{
            .args = &arguments,
            .vtable = &.{
                .create = create,
            },
        };
    };
}

comptime {
    _ = RK4(0);
    _ = RK4(1);
    _ = RK4(2);
    _ = RK4(4);
}

test "Factory" {
    const factory = RK4(0).factory;
    const rk4 = try factory.create(
        std.testing.allocator,
        factory.args,
    );
    defer factory.destroy(rk4);

    const factory_args = factory.getArguments();

    for (rk4.args, 0..) |arg, i| {
        try std.testing.expect(std.mem.eql(u8, arg.name, factory_args[i].name));
        try std.testing.expect(arg.value.f == factory_args[i].value.f);
    }
}
