const std = @import("std");

const zbgfx = @import("zbgfx");

pub fn build(
    b: *std.Build,
    optimize: std.builtin.Mode,
    target: std.Build.ResolvedTarget,
) !void {
    //
    // OPTIONS
    //

    //
    // Dependencies
    //
    const zbgfx_dep = b.dependency(
        "zbgfx",
        .{
            .target = target,
            .optimize = optimize,
        },
    );

    const zglfw = b.dependency(
        "zglfw",
        .{
            .target = target,
            .optimize = optimize,
        },
    );

    const zmath = b.dependency(
        "zmath",
        .{
            .target = target,
            .optimize = optimize,
        },
    );

    const exe = b.addExecutable(.{
        .name = "02-runtime-shaderc",
        .root_source_file = b.path("02-runtime-shaderc/src/main.zig"),
        .target = target,
    });
    b.installArtifact(exe);
    exe.linkLibrary(zbgfx_dep.artifact("bgfx"));

    b.installArtifact(zbgfx_dep.artifact("shaderc"));

    exe.root_module.addImport("zbgfx", zbgfx_dep.module("zbgfx"));
    exe.root_module.addImport("zmath", zmath.module("root"));
    exe.root_module.addImport("zglfw", zglfw.module("root"));

    exe.linkLibrary(zglfw.artifact("glfw"));

    // Install core shaders
    const install_shaders_includes = b.addInstallDirectory(.{
        .install_dir = .header,
        .install_subdir = "shaders",
        .source_dir = zbgfx_dep.path("shaders"),
    });
    exe.step.dependOn(&install_shaders_includes.step);

    // Install example shaders
    const install_example_shaders = b.addInstallDirectory(.{
        .install_dir = .bin,
        .install_subdir = "shaders",
        .source_dir = b.path("02-runtime-shaderc/src"),
        .include_extensions = &.{".sc"},
    });
    exe.step.dependOn(&install_example_shaders.step);
}
