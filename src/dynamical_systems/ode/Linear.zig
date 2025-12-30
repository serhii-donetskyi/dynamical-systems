const ds = @import("dynamical_systems");
const Argument = ds.Argument;
const Ode = ds.ode.Ode;
const std = @import("std");
const Allocator = std.mem.Allocator;
const Linear = @This();

const Data = struct {
    allocator: Allocator,
    n: usize,
    t: f64,
    x: []f64,
    p: []f64,
};

pub fn init(allocator: Allocator, n: usize) !Ode {
    const data = try allocator.create(Data);
    errdefer allocator.destroy(data);
    data.* = .{
        .allocator = allocator,
        .n = n,
        .t = 0.0,
        .x = try allocator.alloc(f64, n),
        .p = try allocator.alloc(f64, n * n),
    };

    inline for ([_]usize{ 32, 16, 8, 4, 2, 0 }) |v_len| {
        if (n >= 2 * v_len)
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

            if (comptime v_len == 0) {
                for (0..data.n) |i| {
                    dxdt[i] = 0.0;
                    for (0..data.n) |j| {
                        dxdt[i] += data.p[i * data.n + j] * x[j];
                    }
                }
            } else {
                const V = @Vector(v_len, f64);
                for (0..data.n) |i| {
                    const k = i * data.n;
                    var tmp = @as(V, @splat(0.0));
                    var j = @as(usize, 0);
                    while (j + v_len <= data.n) : (j += v_len) {
                        tmp = @mulAdd(
                            V,
                            data.p[k + j ..][0..v_len].*,
                            x[j..][0..v_len].*,
                            tmp,
                        );
                    }
                    dxdt[i] = @reduce(.Add, tmp);
                    for (j..data.n) |m| {
                        dxdt[i] += data.p[k + m] * x[m];
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
