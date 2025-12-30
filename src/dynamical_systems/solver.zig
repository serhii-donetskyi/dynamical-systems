const ds = @import("../dynamical_systems.zig");
const Argument = ds.Argument;
const Ode = ds.ode.Ode;

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Solver = struct {
    data: *anyopaque,
    vtable: *const VTable,

    const VTable = struct {
        deinit: *const fn (*Solver) void,
        integrate: *const fn (*Solver, *const Ode, *f64, [*]f64, f64) anyerror!void,
    };

    pub inline fn deinit(self: *Solver) void {
        self.vtable.deinit(self);
    }
    pub inline fn integrate(
        self: *Solver,
        ode: *const Ode,
        t: *f64,
        x: [*]f64,
        t_end: f64,
    ) anyerror!void {
        try self.vtable.integrate(self, ode, t, x, t_end);
    }

    pub const Factory = struct {
        vtable: *const Factory.VTable,

        const VTable = struct {
            init: *const fn (Allocator, []const Argument) anyerror!Solver,
            getArguments: *const fn () []const Argument,
        };

        pub inline fn init(self: Factory, allocator: Allocator, args: []const Argument) anyerror!Solver {
            return self.vtable.init(allocator, args);
        }
        pub inline fn getArguments(self: Factory) []const Argument {
            return self.vtable.getArguments();
        }
    };
};

pub const Euler = struct {
    const Data = struct {
        allocator: Allocator,
        h_max: f64,
        y: []f64,
    };

    pub fn init(allocator: Allocator, h_max: f64) !Solver {
        const data = try allocator.create(Data);
        errdefer allocator.destroy(data);

        data.* = .{
            .allocator = allocator,
            .h_max = h_max,
            .y = try allocator.alloc(f64, 0),
        };

        return .{
            .data = data,
            .vtable = &.{
                .deinit = deinit,
                .integrate = integrate,
            },
        };
    }

    fn deinit(self: *Solver) void {
        const data: *Data = @ptrCast(@alignCast(self.data));
        data.allocator.free(data.y);
        data.allocator.destroy(data);
    }

    fn integrate(self: *Solver, ode: *const Ode, t: *f64, x: [*]f64, t_end: f64) anyerror!void {
        const data: *Data = @ptrCast(@alignCast(self.data));

        const x_dim = ode.getXDim();
        if (data.y.len < x_dim) {
            data.y = try data.allocator.realloc(data.y, x_dim);
        }

        const sign: f64 = if (t_end > t.*) 1.0 else -1.0;
        var h = sign * data.h_max;

        for (0..1_000_000_000) |_| {
            if (sign * (t.* - t_end) >= 0)
                break;
            if (sign * (t.* + h - t_end) >= 0) {
                h = t_end - t.* + sign * 1e-10;
            }
            ode.calc(t.*, x, data.y.ptr);
            for (0..x_dim) |i| {
                x[i] += h * data.y[i];
            }
            t.* += h;
        }
    }

    pub const Factory = struct {
        fn init(allocator: Allocator, args: []const Argument) !Solver {
            return try Euler.init(allocator, args[0].value.f);
        }
        fn getArguments() []const Argument {
            return &[_]Argument{.{
                .name = "h_max",
                .value = .{ .f = 0.01 },
            }};
        }
    };

    pub const factory = Solver.Factory{
        .vtable = &.{
            .init = Factory.init,
            .getArguments = Factory.getArguments,
        },
    };
};

test "factory" {
    var ode = try ds.ode.Constant.init(std.testing.allocator, 2);
    defer ode.deinit();

    var t = ode.getT();
    t = 0.0;
    const x = try std.testing.allocator.alloc(f64, 2);
    defer std.testing.allocator.free(x);
    x[0] = 3.0;
    x[1] = 7.0;

    var solver = try Euler.factory.init(
        std.testing.allocator,
        Euler.factory.getArguments(),
    );
    defer solver.deinit();

    try solver.integrate(&ode, &t, x.ptr, t + 0.1);
    try std.testing.expectApproxEqAbs(t, 0.1, 1e-9);
    try std.testing.expectEqual(x[0], 3.0);
    try std.testing.expectEqual(x[1], 7.0);
}
