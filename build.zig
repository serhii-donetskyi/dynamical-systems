const std = @import("std");

pub fn build(b: *std.Build) !void {
    const allocator = b.allocator;

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // main steps
    const install_step = b.getInstallStep();
    const test_step = b.step("test", "Run tests");
    const run_step = b.step("run", "Run the app");

    // compile the main module
    const mod = b.addModule("dynamical_systems", .{
        .root_source_file = b.path("src/dynamical_systems.zig"),
        .target = target,
    });

    // compile the executable
    const exe = b.addExecutable(.{
        .name = "dynamical-systems",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            // Keep release artifacts lean (esp. on Windows where this can emit .pdb).
            .strip = if (optimize != .Debug) true else null,
            .imports = &.{
                .{
                    .name = "dynamical_systems",
                    .module = mod,
                },
            },
        }),
    });
    const compiled_exe = b.addInstallArtifact(exe, .{
        // Prevent installing/emitting debug symbol sidecar files (e.g. .pdb on Windows).
        .pdb_dir = if (optimize != .Debug) .disabled else .default,
        .implib_dir = if (optimize != .Debug) .disabled else .default,
    });
    install_step.dependOn(&compiled_exe.step);

    // compile executable for tests
    const mod_tests = b.addTest(.{
        .root_module = mod,
    });
    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });
    // run executable for tests
    const run_mod_tests = b.addRunArtifact(mod_tests);
    const run_exe_tests = b.addRunArtifact(exe_tests);

    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);

    // Build dynamic libraries for job/ ode/ solver/ subdirectories
    const cwd = std.fs.cwd();
    inline for ([_][]const u8{ "job", "solver", "ode" }) |dir_name| {
        const dir_path = "src/dynamical_systems/" ++ dir_name;
        var dir = try cwd.openDir(dir_path, .{ .iterate = true });
        defer dir.close();

        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            if (entry.kind == .file) {
                const file_path = try std.fs.path.join(allocator, &.{ dir_path, entry.name });
                defer allocator.free(file_path);
                // compile library
                const lib = b.addLibrary(.{
                    .name = entry.name[0 .. entry.name.len - 4],
                    .linkage = .dynamic,
                    .root_module = b.createModule(.{
                        .root_source_file = b.path(file_path),
                        .imports = &.{
                            .{
                                .name = "dynamical_systems",
                                .module = mod,
                            },
                        },
                        .target = target,
                        .optimize = optimize,
                        // Keep release artifacts lean (esp. on Windows where this can emit .pdb).
                        .strip = if (optimize != .Debug) true else null,
                    }),
                });
                // add options to install library
                const compiled_lib = b.addInstallArtifact(lib, .{
                    .dest_dir = .{ .override = .{ .custom = "lib/" ++ dir_name } },
                    // These libraries are runtime-loaded plugins; we don't need to ship
                    // Windows import libs (.lib) or debug symbol sidecars (.pdb).
                    .implib_dir = if (optimize != .Debug) .disabled else .default,
                    .pdb_dir = if (optimize != .Debug) .disabled else .default,
                });
                install_step.dependOn(&compiled_lib.step);

                // compile executable for a lib
                const lib_tests = b.addTest(.{
                    .root_module = lib.root_module,
                });
                // run executable for a lib
                const run_lib_tests = b.addRunArtifact(lib_tests);
                test_step.dependOn(&run_lib_tests.step);
            }
        }
    }

    // run
    const run_exe = b.addRunArtifact(exe);
    run_exe.step.dependOn(install_step);

    run_step.dependOn(&run_exe.step);

    if (b.args) |args| {
        run_exe.addArgs(args);
    }
}
