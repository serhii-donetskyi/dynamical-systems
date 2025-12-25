const ds = @import("dynamical_systems");
const Argument = ds.Argument;
const Ode = ds.ode.Ode;
const std = @import("std");
const Allocator = std.mem.Allocator;
const Linear = @This();

pub fn init(allocator: Allocator, n: usize) !Ode {
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

    inline for ([_]usize{ 32, 16, 8, 4, 2, 0 }) |v_len| {
        if (x_dim >= 2 * v_len)
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
fn deinit(self: *Ode) void {
    self.allocator.free(self.args);
    self.allocator.free(self.x);
    self.allocator.free(self.p);
}

fn calc(comptime v_len: usize) fn (self: *const Ode, t: f64, x: [*]const f64, dxdt: [*]f64) void {
    return struct {
        fn calc(self: *const Ode, t: f64, x: [*]const f64, dxdt: [*]f64) void {
            @setRuntimeSafety(false);
            @setFloatMode(.optimized);
            _ = t;
            if (comptime v_len == 0) {
                for (0..self.x.len) |i| {
                    dxdt[i] = 0.0;
                    for (0..self.x.len) |j| {
                        dxdt[i] += self.p[i * self.x.len + j] * x[j];
                    }
                }
            } else {
                const V = @Vector(v_len, f64);
                for (0..self.x.len) |i| {
                    const k = i * self.x.len;
                    var tmp = @as(V, @splat(0.0));
                    var j = @as(usize, 0);
                    while (j + v_len <= self.x.len) : (j += v_len) {
                        tmp = @mulAdd(
                            V,
                            self.p[k + j .. k + j + v_len][0..v_len].*,
                            x[j .. j + v_len][0..v_len].*,
                            tmp,
                        );
                    }
                    dxdt[i] = @reduce(.Add, tmp);
                    for (j..self.x.len) |m| {
                        dxdt[i] += self.p[k + m] * x[m];
                    }
                }
            }
        }
    }.calc;
}

const Factory = struct {
    fn init(allocator: Allocator, args: []const Argument) !Ode {
        const n = args[0].value.u;
        return try Linear.init(allocator, n);
    }
    fn getArguments() []const Argument {
        return &[_]Argument{.{
            .name = "n",
            .value = .{ .u = 2 },
            .description = "The dimension of the system",
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
    const x_dim = 2;
    const p_dim = x_dim * x_dim;

    var linear = try factory.init(
        std.testing.allocator,
        &[_]Argument{.{
            .name = "n",
            .value = .{ .u = x_dim },
        }},
    );
    defer linear.deinit();

    const t = @as(f64, 0.0);
    const x = &[x_dim]f64{ 1.0, 1.0 };
    const p = &[p_dim]f64{ 0.0, 1.0, -1.0, 0.0 };
    var dxdt = [x_dim]f64{ 0.0, 0.0 };

    linear.setT(t);
    for (x, 0..) |x_i, i| linear.setX(i, x_i);
    for (p, 0..) |p_i, i| linear.setP(i, p_i);

    linear.calc(t, x.ptr, &dxdt);

    try std.testing.expect(linear.getXDim() == x_dim);
    try std.testing.expect(linear.getPDim() == p_dim);
    try std.testing.expect(dxdt[0] == 1.0);
    try std.testing.expect(dxdt[1] == -1.0);
}
