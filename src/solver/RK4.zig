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
            y: []T,
            k1: []T,
            k2: []T,
            k3: []T,
            k4: []T,

            fn alloc(allocator: Allocator, capacity: u64) !Data {
                const y = try allocator.alloc(T, capacity);
                errdefer allocator.free(y);
                const k1 = try allocator.alloc(T, capacity);
                errdefer allocator.free(k1);
                const k2 = try allocator.alloc(T, capacity);
                errdefer allocator.free(k2);
                const k3 = try allocator.alloc(T, capacity);
                errdefer allocator.free(k3);
                const k4 = try allocator.alloc(T, capacity);
                errdefer allocator.free(k4);

                return .{
                    .capacity = capacity,
                    .y = y,
                    .k1 = k1,
                    .k2 = k2,
                    .k3 = k3,
                    .k4 = k4,
                };
            }

            fn resize(self: *Data, allocator: Allocator, capacity: u64) !void {
                self.free(allocator);
                self.capacity = capacity;
                self.y = try allocator.realloc(self.y, capacity);
                errdefer allocator.free(self.y);
                self.k1 = try allocator.realloc(self.k1, capacity);
                errdefer allocator.free(self.k1);
                self.k2 = try allocator.realloc(self.k2, capacity);
                errdefer allocator.free(self.k2);
                self.k3 = try allocator.realloc(self.k3, capacity);
                errdefer allocator.free(self.k3);
                self.k4 = try allocator.realloc(self.k4, capacity);
                errdefer allocator.free(self.k4);
            }

            fn free(self: Data, allocator: Allocator) void {
                allocator.free(self.y);
                allocator.free(self.k1);
                allocator.free(self.k2);
                allocator.free(self.k3);
                allocator.free(self.k4);
            }
        };

        const arguments = [_]Argument{.{
            .name = "h_max",
            .value = .{ .f = 0.01 },
        }};

        pub const factory = SolverFactory{
            .args = &arguments,
            .vtable = &.{
                .create = factory_create,
            },
        };

        fn factory_create(allocator: Allocator, args: []const Argument) !Solver {
            return try create(allocator, args[0].value.f);
        }

        pub fn create(allocator: Allocator, h_max: f64) !Solver {
            const args = try allocator.alloc(Argument, 1);
            errdefer allocator.free(args);
            args[0] = .{ .name = "h_max", .value = .{ .f = h_max } };

            const capacity = 8;
            const data = try allocator.create(Data);
            errdefer allocator.destroy(data);
            data.* = try Data.alloc(allocator, capacity);
            errdefer data.free(allocator);

            return .{
                .dim = capacity,
                .allocator = allocator,
                .args = args,
                .data = data,
                .vtable = &.{
                    .destroy = destroy,
                    .integrate = integrate,
                },
            };
        }

        fn destroy(self: Solver) void {
            const data: *Data = @ptrCast(@alignCast(self.data));
            data.free(self.allocator);
            self.allocator.destroy(data);
            self.allocator.free(self.args);
        }

        fn integrate(
            noalias self: *Solver,
            noalias ode: *const ODE,
            noalias t: *f64,
            noalias x: [*]T,
            t_end: f64,
        ) !void {
            const data: *Data = @ptrCast(@alignCast(self.data));
            self.dim = ode.get_x_dim();
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
    };
}

comptime {
    _ = RK4(0);
    _ = RK4(1);
    _ = RK4(2);
    _ = RK4(4);
}
