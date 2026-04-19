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

    // zglfw
    const zglfw = b.dependency(
        "zglfw",
        .{
            .target = target,
            .optimize = optimize,
        },
    );
    // ZGUI
    const zgui = b.dependency(
        "zgui",
        .{
            .target = target,
            .optimize = .ReleaseFast,
            .backend = .glfw,
        },
    );

    // ZBgfx
    const zbgfx_dep = b.dependency(
        "zbgfx",
        .{
            .target = target,
            .optimize = optimize,
            .imgui_include = zgui.path("libs").getPath(b),
        },
    );

    const exe = b.addExecutable(.{
        .name = "zgui",
        .root_module = b.createModule(.{
            .root_source_file = b.path("zgui/src/main.zig"),
            .target = target,
        }),
    });
    b.installArtifact(exe);

    exe.root_module.addImport("zgui", zgui.module("root"));
    exe.root_module.addImport("zglfw", zglfw.module("root"));
    exe.root_module.addImport("zbgfx", zbgfx_dep.module("zbgfx"));

    exe.root_module.linkLibrary(zglfw.artifact("glfw"));
    exe.root_module.linkLibrary(zgui.artifact("imgui"));
    exe.root_module.linkLibrary(zbgfx_dep.artifact("bgfx"));
}
