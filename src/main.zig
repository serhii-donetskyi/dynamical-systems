const std = @import("std");
const ds = @import("dynamical_systems");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var solver = try ds.solver.RK4(0).create(allocator, 0.01);
    defer solver.destroy();

    var ode = try ds.ode.Linear(0).create(allocator, 2);
    defer ode.destroy();
    ode.set(.{
        .x = &[_]f64{ 0.0, 1.0 },
        .p = &[_]f64{ 0.0, 1.0, -1.0, 0.0 },
    });

    try solver.integrate(&ode, &ode.t, ode.x.ptr, 1000000);
}
