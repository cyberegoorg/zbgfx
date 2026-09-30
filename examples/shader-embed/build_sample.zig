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

    // This is need only for crosscompilation from linux => windows
    const zbgfx_host_shaderc_dep = b.dependency(
        "zbgfx",
        .{
            .target = b.graph.host,
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
    const zbgfx_module = zbgfx_dep.module("zbgfx");

    //
    // Compile shaders to zig module
    //
    const install_shaderc_step = try zbgfx.build_step.installShaderc(b, zbgfx_host_shaderc_dep);
    const shaders_includes = &.{zbgfx_host_shaderc_dep.path("shaders")};

    const shaders_module = try zbgfx.build_step.compileShaders(
        b,
        target,
        install_shaderc_step,
        zbgfx_host_shaderc_dep,
        zbgfx_module,
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
    exe.root_module.linkLibrary(zbgfx_dep.artifact("bgfx"));
    exe.root_module.addImport("zbgfx", zbgfx_module);
    exe.root_module.addImport("zmath", zmath.module("root"));
    exe.root_module.addImport("zglfw", zglfw.module("root"));
    exe.root_module.addImport("shaders", shaders_module);
    exe.root_module.linkLibrary(zglfw.artifact("glfw"));
}
