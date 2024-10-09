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

    //
    // Compile shaders to zig module
    //
    const zbgfx_module = zbgfx_dep.module("zbgfx");
    const shaderc = zbgfx_dep.artifact("shaderc");
    const combine_bin_zig = zbgfx_dep.artifact("combine_bin_zig");
    const shader_includes = zbgfx_dep.path("shaders");

    const fs_cubes_zig = try zbgfx.build_shader.compileBasicBinZig(
        b,
        target,
        shaderc,
        zbgfx_module,
        combine_bin_zig,
        "fs_cubes.zig",
        .{
            .shaderType = .fragment,
            .input = b.path("00-minimal/src/fs_cubes.sc"),
        },
        .{
            .output = thisDir() ++ "/src/fs_cubes.bin.zig",
            .includes = &.{shader_includes},
        },
    );
    const vs_cubes_zig = try zbgfx.build_shader.compileBasicBinZig(
        b,
        target,
        shaderc,
        zbgfx_module,
        combine_bin_zig,
        "vs_cubes.zig",
        .{
            .shaderType = .vertex,
            .input = b.path("00-minimal/src/vs_cubes.sc"),
        },
        .{
            .output = thisDir() ++ "/src/vs_cubes.bin.zig",
            .includes = &.{shader_includes},
        },
    );

    const exe = b.addExecutable(.{
        .name = "00-minimal",
        .root_source_file = b.path("00-minimal/src/main.zig"),
        .target = target,
    });
    b.installArtifact(exe);
    exe.linkLibrary(zbgfx_dep.artifact("bgfx"));

    exe.root_module.addImport("zbgfx", zbgfx_dep.module("zbgfx"));
    exe.root_module.addImport("fs_cubes", fs_cubes_zig);
    exe.root_module.addImport("vs_cubes", vs_cubes_zig);

    exe.root_module.addImport("zmath", zmath.module("root"));
    exe.root_module.addImport("zglfw", zglfw.module("root"));
    exe.linkLibrary(zglfw.artifact("glfw"));
}

inline fn thisDir() []const u8 {
    return comptime std.fs.path.dirname(@src().file) orelse ".";
}
