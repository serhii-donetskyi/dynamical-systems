const std = @import("std");
const ds = @import("dynamical_systems");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const x_dim = 4;
    const vector_size = 2;
    var solver = try ds.solver.RK4(vector_size).create(allocator, 0.01);
    defer solver.destroy();

    var ode = try ds.ode.Linear(vector_size).create(allocator, x_dim);
    defer ode.destroy();
    ode.set(.{
        .x = &@as([x_dim]f64, @splat(0.0)),
        .p = &@as([x_dim * x_dim]f64, @splat(0.0)),
    });

    try solver.integrate(&ode, &ode.t, ode.x.ptr, 1000000);
}
