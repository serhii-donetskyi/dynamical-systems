const ds = @import("../dynamical_systems.zig");
const Argument = ds.Argument;

const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn RK4(comptime vector_size: u64) type {
    const ODE = ds.ode.ODE(vector_size);
    const Solver = ds.solver.Solver(vector_size);
    const SolverFactory = ds.solver.SolverFactory(vector_size);

    const Data = struct {
        const T = ODE.T;
        const Self = @This();

        y: []T,
        k1: []T,
        k2: []T,
        k3: []T,
        k4: []T,

        fn alloc(allocator: Allocator, n: usize) !*Self {
            const data = try allocator.create(Self);
            errdefer allocator.destroy(data);

            const y = try allocator.alloc(Self, n * 5);

            data.* = .{
                .y = y,
                .k1 = y[n .. 2 * n],
                .k2 = y[2 * n .. 3 * n],
                .k3 = y[3 * n .. 4 * n],
                .k4 = y[4 * n .. 5 * n],
            };
            return data;
        }
        fn free(allocator: Allocator, data: *Self) void {
            allocator.free(data.y);
            allocator.destroy(data);
        }
    };

    return struct {
        pub const T = ODE.T;
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

        pub fn create(allocator: Allocator, h_max: f64) !Solver {
            const args = try allocator.alloc(Argument, 1);
            errdefer allocator.free(args);
            args[0] = .{ .name = "h_max", .value = .{ .f = h_max } };

            const capacity: u64 = 8;
            const data = try Data.alloc(allocator, capacity);

            return .{
                .capacity = capacity,
                .size = 0,
                .args = args,
                .allocator = allocator,
                .data = data,
                .vtable = &.{
                    .destroy = destroy,
                    .prepare = prepare,
                    .step = step,
                },
            };
        }

        fn factory_create(allocator: Allocator, args: []const Argument) !Solver {
            return try create(allocator, args[0].value.f);
        }

        fn destroy(self: Solver) void {
            self.allocator.free(self.args);
            Data.free(self.allocator, self.data);
        }

        fn prepare(self: *Solver, ode: *const ODE) !void {
            const x_len = ode.get_x_len();
            if (self.capacity >= x_len) {
                self.size = x_len;
                return;
            }

            Data.free(self.allocator, self.data);
            self.capacity = 0;
            self.size = 0;

            self.data = try Data.alloc(self.allocator, x_len);
            self.capacity = x_len;
            self.size = self.capacity;
        }

        fn step(
            noalias self: *const Solver,
            noalias ode: *const ODE,
            noalias t: *f64,
            noalias x: [*]T,
            t_end: f64,
        ) void {
            std.debug.assert(self.size == ode.get_x_len());
            const data: *Data = @ptrCast(@alignCast(self.data));
            const h_max = self.args[0].value.f;
            const sign = if (t_end > *t) 1 else -1;
            var h = sign * h_max;

            for (0..1_000_000_000) |_| {}
        }
    };
}

comptime {
    _ = RK4(0);
    _ = RK4(1);
    _ = RK4(2);
    _ = RK4(4);
}
