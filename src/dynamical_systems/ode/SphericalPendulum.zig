const ds = @import("dynamical_systems");
const Argument = ds.Argument;
const Ode = ds.ode.Ode;
const std = @import("std");
const Allocator = std.mem.Allocator;
const SphericalPendulum = @This();

const Data = struct {
    allocator: Allocator,
    t: f64,
    x: []f64,
    p: []f64,
};

fn init(allocator: Allocator) anyerror!Ode {
    const data = try allocator.create(Data);
    errdefer allocator.destroy(data);
    data.* = .{
        .allocator = allocator,
        .t = 0.0,
        .x = try allocator.alloc(f64, 5),
        .p = try allocator.alloc(f64, 4),
    };

    return .{
        .data = data,
        .vtable = &.{
            .deinit = deinit,
            .calc = calc,
            .getT = getT,
            .getX = getX,
            .getP = getP,
        },
    };
}

fn deinit(self: *Ode) void {
    const data: *Data = @ptrCast(@alignCast(self.data));
    data.allocator.free(data.x);
    data.allocator.free(data.p);
    data.allocator.destroy(data);
}

fn calc(self: *const Ode, t: f64, x: [*]const f64, dxdt: [*]f64) void {
    @setRuntimeSafety(false);
    @setFloatMode(.optimized);
    _ = t;
    const data: *Data = @ptrCast(@alignCast(self.data));

    const tmp2 = (x[0] * x[4] - x[1] * x[3]) * 0.75;
    const tmp1 = x[2] + (x[0] * x[0] + x[1] * x[1] + x[3] * x[3] + x[4] * x[4]) / 8;
    dxdt[0] = data.p[0] * x[0] - tmp1 * x[1] - tmp2 * x[3] + 2 * x[1];
    dxdt[1] = data.p[0] * x[1] + tmp1 * x[0] - tmp2 * x[4] + 2 * x[0];
    dxdt[2] = data.p[1] * (x[0] * x[1] + x[3] * x[4]) + data.p[2] * x[2] + data.p[3];
    dxdt[3] = data.p[0] * x[3] - tmp1 * x[4] + tmp2 * x[0] + 2 * x[4];
    dxdt[4] = data.p[0] * x[4] + tmp1 * x[3] + tmp2 * x[1] + 2 * x[3];
}

fn getT(self: *const Ode) *f64 {
    const data: *Data = @ptrCast(@alignCast(self.data));
    return &data.t;
}
fn getX(self: *const Ode) []f64 {
    const data: *Data = @ptrCast(@alignCast(self.data));
    return data.x;
}
fn getP(self: *const Ode) []f64 {
    const data: *Data = @ptrCast(@alignCast(self.data));
    return data.p;
}

const Factory = struct {
    fn init(allocator: Allocator, args: []const Argument) !Ode {
        _ = args;
        return try SphericalPendulum.init(allocator);
    }
    fn getArguments() []const Argument {
        return &[_]Argument{};
    }
    fn factory() Ode.Factory {
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
    var ode = try factory.init(
        std.testing.allocator,
        factory.getArguments(),
    );
    defer ode.deinit();
}
