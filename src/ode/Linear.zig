const ds = @import("../dynamical_systems.zig");
const Argument = ds.Argument;
const ODE = ds.ode.ODE;

const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn Linear(comptime v_len: usize) type {
    return struct {
        pub fn init(allocator: Allocator, n: u64) !ODE {
            const t = 0.0;

            const args = try allocator.alloc(Argument, 1);
            errdefer allocator.free(args);
            args[0] = .{ .name = "n", .value = .{ .u = n } };

            const x_dim = n;
            const x = try allocator.alloc(f64, x_dim);
            errdefer allocator.free(x);
            for (0..x_dim) |i| x[i] = 0.0;

            const p_dim = x_dim * x_dim;
            const p = try allocator.alloc(f64, p_dim);
            errdefer allocator.free(p);
            for (0..p_dim) |i| p[i] = 0.0;

            return .{
                .allocator = allocator,
                .args = args,
                .x_dim = x_dim,
                .p_dim = p_dim,
                .t = t,
                .x = x,
                .p = p,
                .vtable = &.{
                    .deinit = deinit,
                    .calc = calc,
                    .getT = getT,
                    .getX = getX,
                    .getP = getP,
                    .setT = setT,
                    .setX = setX,
                    .setP = setP,
                },
            };
        }
        fn deinit(self: *ODE) void {
            self.allocator.free(self.args);
            self.allocator.free(self.x);
            self.allocator.free(self.p);
        }
        fn calc(self: *const ODE, t: f64, x: [*]const f64, dxdt: [*]f64) void {
            @setRuntimeSafety(false);
            @setFloatMode(.optimized);
            _ = t;
            if (comptime v_len == 0) {
                for (0..self.x_dim) |i| {
                    for (0..self.x_dim) |j| {
                        dxdt[i] += self.p[i * self.x_dim + j] * x[j];
                    }
                }
            } else {
                const V = @Vector(v_len, f64);
                for (0..self.x_dim) |i| {
                    const k = i * self.x_dim;
                    var tmp = @as(V, @splat(0.0));
                    var j = @as(usize, 0);
                    while (j + v_len <= self.x_dim) : (j += v_len) {
                        tmp = @mulAdd(
                            V,
                            self.p[k + j .. k + j + v_len][0..v_len].*,
                            x[j .. j + v_len][0..v_len].*,
                            tmp,
                        );
                    }
                    dxdt[i] = @reduce(.Add, tmp);
                    for (j..self.x_dim) |m| {
                        dxdt[i] += self.p[k + m] * x[m];
                    }
                }
            }
        }
        fn getT(self: ODE) f64 {
            return self.t;
        }
        fn getX(self: ODE, i: usize) f64 {
            return if (i < self.x_dim) self.x[i] else 0.0;
        }
        fn getP(self: ODE, i: usize) f64 {
            return if (i < self.p_dim) self.p[i] else 0.0;
        }
        fn setT(self: *ODE, t: f64) void {
            self.t = t;
        }
        fn setX(self: *ODE, x: []const f64) void {
            for (0..self.x_dim) |i|
                self.x[i] = if (i < x.len) x[i] else 0.0;
        }
        fn setP(self: *ODE, p: []const f64) void {
            for (0..self.p_dim) |i|
                self.p[i] = if (i < p.len) p[i] else 0.0;
        }
    };
}

fn create(allocator: Allocator, args: []const Argument) !ODE {
    const n = args[0].value.u;
    inline for ([_]usize{ 32, 16, 8, 4, 2 }) |v_len| {
        if (n >= v_len)
            return try Linear(v_len).init(allocator, n);
    }
    return try Linear(0).init(allocator, n);
}
fn getArguments() []const Argument {
    const arguments = comptime [_]Argument{.{
        .name = "n",
        .value = .{ .u = 2 },
    }};
    return &arguments;
}
pub const factory = ODE.Factory{
    .vtable = &.{
        .create = create,
        .getArguments = getArguments,
    },
};

comptime {
    _ = Linear(0);
    _ = Linear(1);
    _ = Linear(2);
    _ = Linear(4);
}

test "Factory" {
    const n = 2;

    var linear = try factory.create(
        std.testing.allocator,
        &[_]Argument{.{
            .name = "n",
            .value = .{ .u = n },
        }},
    );
    defer factory.destroy(linear);

    const t = @as(f64, 0.0);
    const x = &[_]f64{ 1.0, 1.0 };
    const p = &[_]f64{ 0.0, 1.0, -1.0, 0.0 };
    var dxdt = [_]f64{ 0.0, 0.0 };

    linear.setT(t);
    linear.setX(x);
    linear.setP(p);

    linear.calc(t, linear.x.ptr, &dxdt);

    try std.testing.expect(2 == linear.x_dim);
    try std.testing.expect(4 == linear.p_dim);
    try std.testing.expect(1.0 == dxdt[0]);
    try std.testing.expect(-1.0 == dxdt[1]);
}
