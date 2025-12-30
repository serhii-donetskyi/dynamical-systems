const ds = @import("dynamical_systems");
const Argument = ds.Argument;
const Ode = ds.ode.Ode;
const std = @import("std");
const Allocator = std.mem.Allocator;
const TankFluidFD = @This();

const Data = struct {
    allocator: Allocator,
    m: usize,
    t: f64,
    x: []f64,
    p: []f64,
};

fn init(allocator: Allocator, m: usize) anyerror!Ode {
    const data = try allocator.create(Data);
    errdefer allocator.destroy(data);
    data.* = .{
        .allocator = allocator,
        .m = m,
        .t = 0.0,
        .x = try allocator.alloc(f64, 5 + 2 * m),
        .p = try allocator.alloc(f64, 8),
    };

    inline for ([_]usize{ 32, 16, 8, 4, 2, 0 }) |v_len| {
        if (m >= 2 * v_len + 1 or v_len == 0)
            return .{
                .data = data,
                .vtable = &.{
                    .deinit = deinit,
                    .calc = calc(v_len),
                    .getT = getT,
                    .getX = getX,
                    .getP = getP,
                },
            };
    }
}

fn deinit(self: *Ode) void {
    const data: *Data = @ptrCast(@alignCast(self.data));
    data.allocator.free(data.x);
    data.allocator.free(data.p);
    data.allocator.destroy(data);
}

fn calc(comptime v_len: usize) fn (self: *const Ode, t: f64, x: [*]const f64, dxdt: [*]f64) void {
    return struct {
        fn calc(self: *const Ode, t: f64, x: [*]const f64, dxdt: [*]f64) void {
            @setRuntimeSafety(false);
            @setFloatMode(.optimized);
            _ = t;
            const data: *Data = @ptrCast(@alignCast(self.data));
            const m = data.m;

            const tmp2 = (x[0] * x[4] - x[1] * x[3]) * data.p[2];
            if (m == 0) {
                const tmp1 = x[2] + data.p[1] / 2 * (x[0] * x[0] + x[1] * x[1] + x[3] * x[3] + x[4] * x[4]);
                dxdt[0] = data.p[0] * x[0] - tmp1 * x[1] + tmp2 * x[3];
                dxdt[1] = data.p[0] * x[1] + tmp1 * x[0] + tmp2 * x[4] + 1;
                dxdt[2] = data.p[3] + data.p[4] * x[2] - data.p[5] * x[1];
                dxdt[3] = data.p[0] * x[3] - tmp1 * x[4] - tmp2 * x[0];
                dxdt[4] = data.p[0] * x[4] + tmp1 * x[3] - tmp2 * x[1];
            } else {
                const delay_idx = 5 + 2 * (m - 1);
                const tmp1 = x[delay_idx + 1] + data.p[1] / 2 * (x[0] * x[0] + x[1] * x[1] + x[3] * x[3] + x[4] * x[4]);
                dxdt[0] = data.p[0] * x[0] - tmp1 * x[1] + tmp2 * x[3];
                dxdt[1] = data.p[0] * x[1] + tmp1 * x[0] + tmp2 * x[4] + 1;
                dxdt[2] = data.p[3] + data.p[4] * x[2] - data.p[5] * x[delay_idx];
                dxdt[3] = data.p[0] * x[3] - tmp1 * x[4] - tmp2 * x[0];
                dxdt[4] = data.p[0] * x[4] + tmp1 * x[3] - tmp2 * x[1];

                const delta_coef = @as(f64, @floatFromInt(m)) / data.p[6];
                const rho_coef = @as(f64, @floatFromInt(m)) / data.p[7];
                dxdt[5] = delta_coef * (x[1] - x[5]);
                dxdt[6] = rho_coef * (x[3] - x[6]);

                if (comptime v_len == 0) {
                    for (1..m) |i| {
                        const idx = 5 + 2 * i;
                        dxdt[idx] = delta_coef * (x[idx - 2] - x[idx]);
                        dxdt[idx + 1] = rho_coef * (x[idx - 1] - x[idx + 1]);
                    }
                } else {
                    const V = @Vector(v_len, f64);

                    const coef_vec: V = blk: {
                        const tmp = .{ delta_coef, rho_coef } ** (v_len / 2);
                        break :blk tmp;
                    };
                    var i = @as(usize, 7);
                    while (i < data.x.len) : (i += v_len) {
                        const v1 = @as(V, x[i..][0..v_len].*);
                        const v2 = @as(V, x[i - 2 ..][0..v_len].*);
                        dxdt[i..][0..v_len].* = coef_vec * (v1 - v2);
                    }
                }
            }
        }
    }.calc;
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
