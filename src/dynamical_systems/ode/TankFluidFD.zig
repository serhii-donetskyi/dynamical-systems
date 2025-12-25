const ds = @import("dynamical_systems");
const Argument = ds.Argument;
const Ode = ds.ode.Ode;
const std = @import("std");
const Allocator = std.mem.Allocator;
const TankFluidFD = @This();

pub fn init(allocator: Allocator, m: usize) anyerror!Ode {
    const t = 0.0;

    const args = try allocator.alloc(Argument, 1);
    errdefer allocator.free(args);
    args[0] = .{ .name = "m", .value = .{ .u = m } };

    const x_dim = 5 + 2 * m;
    const x = try allocator.alloc(f64, x_dim);
    errdefer allocator.free(x);
    for (0..x_dim) |i| x[i] = 0.0;

    const p_dim = 7;
    const p = try allocator.alloc(f64, p_dim);
    errdefer allocator.free(p);
    for (0..p_dim) |i| p[i] = 0.0;

    inline for ([_]usize{ 32, 16, 8, 4, 2, 0 }) |v_len| {
        if (m >= 2 * v_len + 1 or v_len == 0)
            return .{
                .allocator = allocator,
                .args = args,
                .t = t,
                .x = x,
                .p = p,
                .vtable = &.{
                    .deinit = deinit,
                    .calc = calc(v_len),
                },
            };
    }
}

pub fn deinit(self: *Ode) void {
    self.allocator.free(self.args);
    self.allocator.free(self.x);
    self.allocator.free(self.p);
}

pub fn calc(comptime v_len: usize) fn (self: *const Ode, t: f64, x: [*]const f64, dxdt: [*]f64) void {
    return struct {
        fn calc(self: *const Ode, t: f64, x: [*]const f64, dxdt: [*]f64) void {
            @setRuntimeSafety(false);
            @setFloatMode(.optimized);
            _ = t;
            const m = self.args[0].value.u;

            const tmp2 = (x[0] * x[4] - x[1] * x[3]) * self.p[2];
            if (m == 0) {
                const tmp1 = x[2] + self.p[1] / 2 * (x[0] * x[0] + x[1] * x[1] + x[3] * x[3] + x[4] * x[4]);
                dxdt[0] = self.p[0] * x[0] - tmp1 * x[1] + tmp2 * x[3];
                dxdt[1] = self.p[0] * x[1] + tmp1 * x[0] + tmp2 * x[4] + 1;
                dxdt[2] = self.p[3] + self.p[4] * x[2] - self.p[5] * x[1];
                dxdt[3] = self.p[0] * x[3] - tmp1 * x[4] - tmp2 * x[0];
                dxdt[4] = self.p[0] * x[4] + tmp1 * x[3] - tmp2 * x[1];
            } else {
                const delay_idx = 5 + 2 * (m - 1);
                const tmp1 = x[delay_idx + 1] + self.p[1] / 2 * (x[0] * x[0] + x[1] * x[1] + x[3] * x[3] + x[4] * x[4]);
                dxdt[0] = self.p[0] * x[0] - tmp1 * x[1] + tmp2 * x[3];
                dxdt[1] = self.p[0] * x[1] + tmp1 * x[0] + tmp2 * x[4] + 1;
                dxdt[2] = self.p[3] + self.p[4] * x[2] - self.p[5] * x[delay_idx];
                dxdt[3] = self.p[0] * x[3] - tmp1 * x[4] - tmp2 * x[0];
                dxdt[4] = self.p[0] * x[4] + tmp1 * x[3] - tmp2 * x[1];

                const coef = @as(f64, @floatFromInt(m)) / self.p[6];
                dxdt[5] = coef * (x[1] - x[5]);
                dxdt[6] = coef * (x[3] - x[6]);

                if (comptime v_len == 0) {
                    for (1..m) |i| {
                        const idx = 5 + 2 * i;
                        dxdt[idx] = coef * (x[idx - 2] - x[idx]);
                        dxdt[idx + 1] = coef * (x[idx - 1] - x[idx + 1]);
                    }
                } else {
                    const V = @Vector(v_len, f64);

                    const coef_vec = @as(V, @splat(coef));
                    var i = @as(usize, 7);
                    while (i < self.x.len) : (i += v_len) {
                        const v1 = @as(V, x[i .. i + v_len][0..v_len].*);
                        const v2 = @as(V, x[i - 2 .. i - 2 + v_len][0..v_len].*);
                        dxdt[i .. i + v_len][0..v_len].* = coef_vec * (v1 - v2);
                    }
                }
            }
        }
    }.calc;
}

const Factory = struct {
    fn init(allocator: Allocator, args: []const Argument) !Ode {
        const n = args[0].value.u;
        return try TankFluidFD.init(allocator, n);
    }
    fn getArguments() []const Argument {
        return &[_]Argument{.{
            .name = "m",
            .value = .{ .u = 0 },
            .description = "The number of Differences in Finite Difference Method for delay approximation",
        }};
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
