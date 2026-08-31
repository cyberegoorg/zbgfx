const std = @import("std");

const Lib = enum(u8) {
    bx = 1,
    bimg = 2,
    bgfx = 3,
};

const LibSyncConfig = struct {
    lib: Lib,
    entries: []const []const u8,
};

const SyncConfig = struct {
    libs: []const LibSyncConfig,
    shaders: []const []const u8,
};

const LIB_DIR = "libs";
const SHADER_DIR = "shaders";

const sync_list = SyncConfig{
    .libs = &.{
        .{
            .lib = .bx,
            .entries = &.{
                "3rdparty/ini",
                "include",
                "src",
                ".gitattributes",
                ".gitignore",
                "LICENSE",
                "README.md",
            },
        },
        .{
            .lib = .bimg,
            .entries = &.{
                "3rdparty",
                "include",
                "src",
                ".gitattributes",
                ".gitignore",
                "LICENSE",
                "README.md",
            },
        },
        .{
            .lib = .bgfx,
            .entries = &.{
                "3rdparty/d3d4linux",
                "3rdparty/dawn",
                "3rdparty/directx-headers",
                "3rdparty/fcpp",
                "3rdparty/glsl-optimizer",
                "3rdparty/glslang",
                "3rdparty/khronos",
                "3rdparty/metal-cpp",
                "3rdparty/renderdoc",
                "3rdparty/spirv-cross",
                "3rdparty/spirv-headers",
                "3rdparty/spirv-tools",

                "bindings/zig",

                "examples/common/debugdraw",
                "examples/common/args.h",
                "examples/common/bgfx_utils.h",
                "examples/common/packrect.h",

                "tools/bin/linux/libdxcompiler.so",
                "tools/bin/linux/libdxil.so",
                "tools/bin/windows/d3d4linux.exe",
                "tools/bin/windows/d3dcompiler_47.dll",
                "tools/bin/windows/dxcompiler.dll",
                "tools/bin/windows/dxil.dll",
                "tools/shaderc",

                "include",
                "src",
                ".gitattributes",
                ".gitignore",
                "LICENSE",
                "README.md",
            },
        },
    },
    .shaders = &.{
        "src/bgfx_compute.sh",
        "src/bgfx_shader.sh",
        "examples/common/shaderlib.sh",
    },
};

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();

    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len < 4) fatal("wrong number of arguments {d}", .{args.len});

    // Libs
    for (sync_list.libs) |config| {
        var lib_dir = try std.Io.Dir.cwd().openDir(init.io, LIB_DIR, .{});
        defer lib_dir.close(init.io);

        const repo_src = args[@intFromEnum(config.lib)];

        var src_dir = try std.Io.Dir.cwd().openDir(init.io, repo_src, .{});
        defer src_dir.close(init.io);

        const lib_dir_name = @tagName(config.lib);

        try lib_dir.deleteTree(init.io, lib_dir_name);
        try lib_dir.createDir(init.io, lib_dir_name, .default_dir);

        for (config.entries) |entry| {
            const stat = src_dir.statFile(init.io, entry, .{}) catch |e| {
                switch (e) {
                    error.FileNotFound => {
                        std.log.err("File {s} not found", .{entry});
                        continue;
                    },
                    else => return e,
                }
            };

            if (stat.kind == .file) {
                std.log.info("Copy file {s}", .{entry});

                const dest_path = blk: {
                    if (std.fs.path.dirname(entry)) |dirname| {
                        break :blk try std.fs.path.join(arena, &.{ lib_dir_name, dirname });
                    }
                    break :blk try std.fs.path.join(arena, &.{lib_dir_name});
                };

                try lib_dir.createDirPath(init.io, dest_path);

                var dest_dir = try lib_dir.openDir(init.io, dest_path, .{});
                defer dest_dir.close(init.io);

                try src_dir.copyFile(entry, dest_dir, std.fs.path.basename(entry), init.io, .{});
            } else if (stat.kind == .directory) {
                // TODO: zig based dir copy
                const from_path = try std.fs.path.join(arena, &.{ repo_src, entry });
                const to_path = try std.fs.path.join(arena, &.{ LIB_DIR, lib_dir_name, entry });
                const to_lib_path = try std.fs.path.join(arena, &.{ lib_dir_name, entry });
                try lib_dir.createDirPath(init.io, to_lib_path);

                std.log.info("Copy dir {s} => {s}   ", .{ from_path, to_path });

                _ = try std.process.run(arena, init.io, .{
                    .argv = &.{
                        "cp",
                        "-rT",
                        from_path,
                        to_path,
                    },
                });
            }
        }
    }

    //
    // Shaders.
    //
    for (sync_list.shaders) |shader| {
        var lib_dir = try std.Io.Dir.cwd().openDir(init.io, SHADER_DIR, .{});
        defer lib_dir.close(init.io);

        const repo_src = args[3];

        var src_dir = try std.Io.Dir.cwd().openDir(init.io, repo_src, .{});
        defer src_dir.close(init.io);

        std.log.info("Copy file {s}", .{shader});

        try src_dir.copyFile(shader, lib_dir, std.fs.path.basename(shader), init.io, .{});
    }

    return std.process.cleanExit(init.io);
}

fn fatal(comptime format: []const u8, args: anytype) noreturn {
    std.debug.print(format, args);
    std.process.exit(1);
}
