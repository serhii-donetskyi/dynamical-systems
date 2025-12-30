const ds = @import("../dynamical_systems.zig");
const Argument = ds.Argument;

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Ode = struct {
    data: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        deinit: *const fn (*Ode) void,
        calc: *const fn (*const Ode, f64, [*]const f64, [*]f64) void,
        getT: *const fn (*const Ode) *f64,
        getX: *const fn (*const Ode) []f64,
        getP: *const fn (*const Ode) []f64,
    };

    pub inline fn deinit(self: *Ode) void {
        self.vtable.deinit(self);
    }
    pub inline fn calc(self: *const Ode, t: f64, x: [*]const f64, dxdt: [*]f64) void {
        self.vtable.calc(self, t, x, dxdt);
    }
    pub inline fn getXDim(self: *const Ode) usize {
        return self.vtable.getX(self).len;
    }
    pub inline fn getPDim(self: *const Ode) usize {
        return self.vtable.getP(self).len;
    }
    pub inline fn getT(self: *const Ode) f64 {
        return self.vtable.getT(self).*;
    }
    pub inline fn getX(self: *const Ode, i: usize) f64 {
        const x = self.vtable.getX(self);
        return if (i < x.len) x[i] else 0.0;
    }
    pub inline fn getP(self: *const Ode, i: usize) f64 {
        const p = self.vtable.getP(self);
        return if (i < p.len) p[i] else 0.0;
    }
    pub inline fn setT(self: *Ode, t: f64) void {
        self.vtable.getT(self).* = t;
    }
    pub inline fn setX(self: *Ode, i: usize, value: f64) void {
        const x = self.vtable.getX(self);
        if (i < x.len) x[i] = value;
    }
    pub inline fn setP(self: *Ode, i: usize, value: f64) void {
        const p = self.vtable.getP(self);
        if (i < p.len) p[i] = value;
    }

    pub const Factory = struct {
        vtable: *const Factory.VTable,

        pub const VTable = struct {
            init: *const fn (Allocator, []const Argument) anyerror!Ode,
            getArguments: *const fn () []const Argument,
        };

        pub inline fn init(self: Factory, allocator: Allocator, args: []const Argument) anyerror!Ode {
            var ode = try self.vtable.init(allocator, args);
            ode.setT(0.0);
            for (0..ode.getXDim()) |i| {
                ode.setX(i, 0.0);
            }
            for (0..ode.getPDim()) |i| {
                ode.setP(i, 0.0);
            }
            return ode;
        }
        pub inline fn getArguments(self: Factory) []const Argument {
            return self.vtable.getArguments();
        }
    };
};

pub const Constant = struct {
    const Data = struct {
        allocator: Allocator,
        n: usize,
        t: f64,
        x: []f64,
    };

    pub fn init(allocator: Allocator, n: usize) !Ode {
        const data = try allocator.create(Data);
        errdefer allocator.destroy(data);
        data.* = .{
            .allocator = allocator,
            .n = n,
            .t = 0.0,
            .x = try allocator.alloc(f64, n),
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
        data.allocator.destroy(data);
    }

    fn calc(self: *const Ode, t: f64, x: [*]const f64, dxdt: [*]f64) void {
        _ = t;
        _ = x;
        const data: *Data = @ptrCast(@alignCast(self.data));
        for (0..data.n) |i| {
            dxdt[i] = 0;
        }
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
        _ = self;
        return &[_]f64{};
    }

    pub const Factory = struct {
        fn init(allocator: Allocator, args: []const Argument) !Ode {
            const n = args[0].value.u;
            return try Constant.init(allocator, n);
        }
        fn getArguments() []const Argument {
            return &[_]Argument{.{
                .name = "n",
                .value = .{ .u = 2 },
                .description = "The dimension of the system",
            }};
        }
    };

    pub const factory = Ode.Factory{
        .vtable = &.{
            .init = Factory.init,
            .getArguments = Factory.getArguments,
        },
    };
};

test "factory" {
    var ode = try Constant.factory.init(
        std.testing.allocator,
        Constant.factory.getArguments(),
    );
    defer ode.deinit();
}
