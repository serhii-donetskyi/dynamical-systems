const ds = @import("../dynamical_systems.zig");
const Argument = ds.Argument;
const ODE = ds.ode.ODE;
const ODEFactory = ds.ode.ODEFactory;

const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn create(allocator: Allocator, n: u64) !ODE {
    const t = 0.0;

    const x = try allocator.alloc(f64, n);
    errdefer allocator.free(x);

    const p = try allocator.alloc(f64, n * n);
    errdefer allocator.free(p);

    const arguments = try allocator.alloc(Argument, 2);
    errdefer allocator.free(arguments);
    arguments[0] = .{ .name = "n", .value = .{ .u = n } };

    return .{
        .allocator = allocator,
        .args = arguments,
        .t = t,
        .x = x,
        .p = p,
        .vtable = &.{
            .destroy = destroy,
            .calc = calc,
        },
    };
}

fn destroy(self: ODE) void {
    self.allocator.free(self.x);
    self.allocator.free(self.p);
    self.allocator.free(self.args);
}

fn calc(noalias self: *const ODE, t: f64, noalias x: [*]const f64, noalias dxdt: [*]f64) void {
    _ = t;
    const n = self.args[0].value.u;
    for (0..n) |i| {
        dxdt[i] = 0;
        for (0..n) |j| {
            dxdt[i] += self.p[i * n + j] * x[j];
        }
    }
}

fn factory_create(allocator: Allocator, arguments: []const Argument) !ODE {
    return try create(allocator, arguments[0].value.u);
}

const args = [_]Argument{
    .{ .name = "n", .value = .{ .u = 2 } },
};

pub const factory = ODEFactory{
    .args = &args,
    .vtable = &.{
        .create = factory_create,
    },
};

test "test linear factory" {
    var linear = try factory.create(
        std.testing.allocator,
        args[0..],
    );
    defer linear.destroy();

    linear.set(.{
        .t = 2.0,
        .x = &[_]f64{ 1.0, -1.0 },
        .p = &[_]f64{ 0.0, 1.0, -1.0, 0.0 },
    });

    var dxdt = [2]f64{ 0.0, 0.0 };
    linear.calc(linear.t, linear.x.ptr, &dxdt);
    try std.testing.expect(linear.t == 2.0);
    try std.testing.expect(dxdt[0] == -1.0);
    try std.testing.expect(dxdt[1] == -1.0);
}
