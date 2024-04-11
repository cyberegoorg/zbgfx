const std = @import("std");

const zbgfx = @import("zbgfx");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

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
            .optimize = optimize,
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
        .name = "minimal-zgui",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
    });
    b.installArtifact(exe);

    exe.root_module.addImport("zgui", zgui.module("root"));
    exe.root_module.addImport("zglfw", zglfw.module("root"));
    exe.root_module.addImport("zbgfx", zbgfx_dep.module("zbgfx"));

    exe.linkLibrary(zglfw.artifact("glfw"));
    exe.linkLibrary(zgui.artifact("imgui"));
    exe.linkLibrary(zbgfx_dep.artifact("bgfx"));
}
