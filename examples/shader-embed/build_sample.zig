const std = @import("std");

const zbgfx = @import("zbgfx");

pub fn build(
    b: *std.Build,
    optimize: std.builtin.OptimizeMode,
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

    //
    // Compile shaders to zig module
    //
    const install_shaderc_step = try zbgfx.build_step.installShaderc(b, zbgfx_dep);
    const shaders_includes = &.{zbgfx_dep.path("shaders")};

    const shaders_module = try zbgfx.build_step.compileShaders(
        b,
        target,
        install_shaderc_step,
        zbgfx_dep,
        shaders_includes,
        &.{
            .{
                .name = "fs_cubes",
                .shaderType = .fragment,
                .path = b.path("shader-embed/src/fs_cubes.sc"),
            },
            .{
                .name = "vs_cubes",
                .shaderType = .vertex,
                .path = b.path("shader-embed/src/vs_cubes.sc"),
            },
        },
    );

    const exe = b.addExecutable(.{
        .name = "shader-embed",
        .root_module = b.createModule(.{
            .root_source_file = b.path("shader-embed/src/main.zig"),
            .target = target,
        }),
    });
    b.installArtifact(exe);
    exe.linkLibrary(zbgfx_dep.artifact("bgfx"));

    exe.root_module.addImport("zbgfx", zbgfx_dep.module("zbgfx"));
    exe.root_module.addImport("zmath", zmath.module("root"));
    exe.root_module.addImport("zglfw", zglfw.module("root"));

    exe.root_module.addImport("shaders", shaders_module);

    exe.linkLibrary(zglfw.artifact("glfw"));
}
