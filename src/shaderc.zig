const std = @import("std");
const builtin = @import("builtin");

const bgfx = @import("bgfx");

const ArgsList = std.ArrayList([]const u8);

pub const ShaderType = enum {
    vertex,
    fragment,
    compute,

    pub fn toStr(t: ShaderType) [:0]const u8 {
        return @tagName(t);
    }

    pub fn toChar(t: ShaderType) u8 {
        return @tagName(t)[0];
    }

    pub fn addAsArg(t: ShaderType, step: *std.Build.Step.Run) void {
        step.addArgs(&.{ "--type", t.toStr() });
    }

    pub fn appendArg(t: ShaderType, alloctor: std.mem.Allocator, args: *ArgsList) !void {
        try args.appendSlice(alloctor, &.{ "--type", t.toStr() });
    }
};

pub const Optimize = enum(u32) {
    o0 = 0,
    o1 = 1,
    o2 = 2,
    o3 = 3,

    pub fn toStr(optimize: Optimize) [:0]const u8 {
        return switch (optimize) {
            .o0 => "0",
            .o1 => "1",
            .o2 => "2",
            .o3 => "3",
        };
    }

    pub fn addAsArg(t: Optimize, step: *std.Build.Step.Run) void {
        step.addArgs(&.{ "-O", t.toStr() });
    }

    pub fn appendArg(t: Optimize, alloctor: std.mem.Allocator, args: *ArgsList) !void {
        try args.appendSlice(alloctor, &.{ "-O", t.toStr() });
    }
};

pub const Platform = enum {
    android,
    asm_js,
    ios,
    linux,
    orbis,
    osx,
    windows,

    pub fn toStr(platform: Platform) [:0]const u8 {
        return switch (platform) {
            .asm_js => "asm.js",
            else => |e| @tagName(e),
        };
    }

    pub fn addAsArg(platform: Platform, step: *std.Build.Step.Run) void {
        step.addArgs(&.{ "--platform", platform.toStr() });
    }

    pub fn appendArg(platform: Platform, alloctor: std.mem.Allocator, args: *ArgsList) !void {
        try args.appendSlice(alloctor, &.{ "--platform", platform.toStr() });
    }
};

pub const Profile = enum {
    es_100,
    es_300,
    es_310,
    es_320,

    s_4_0,
    s_5_0,

    s_6_0,
    s_6_1,
    s_6_2,
    s_6_3,
    s_6_4,
    s_6_5,
    s_6_6,
    s_6_7,
    s_6_8,
    s_6_9,

    metal,
    metal10_10,
    metal11_10,
    metal12_10,
    metal20_11,
    metal21_11,
    metal22_11,
    metal23_14,
    metal24_14,
    metal30_14,
    metal31_14,

    pssl,

    spirv,
    spirv10_10,
    spirv13_11,
    spirv14_11,
    spirv15_12,
    spirv16_13,

    glsl_120,
    glsl_130,
    glsl_140,
    glsl_150,
    glsl_330,
    glsl_400,
    glsl_410,
    glsl_420,
    glsl_430,
    glsl_440,

    pub fn toStr(profile: Profile) [:0]const u8 {
        return switch (profile) {
            // ES
            .es_100 => "100_es",
            .es_300 => "300_es",
            .es_310 => "310_es",
            .es_320 => "320_es",

            // Metal
            .metal10_10 => "metal10-10",
            .metal11_10 => "metal11-10",
            .metal12_10 => "metal12-10",
            .metal20_11 => "metal20-11",
            .metal21_11 => "metal21-11",
            .metal22_11 => "metal22-11",
            .metal23_14 => "metal23-14",
            .metal24_14 => "metal24-14",
            .metal30_14 => "metal30-14",
            .metal31_14 => "metal31-14",

            // SPIRV
            .spirv10_10 => "spirv10-10",
            .spirv13_11 => "spirv13-11",
            .spirv14_11 => "spirv14-11",
            .spirv15_12 => "spirv15-12",
            .spirv16_13 => "spirv16-13",

            // GLSL
            .glsl_120 => "120",
            .glsl_130 => "130",
            .glsl_140 => "140",
            .glsl_150 => "150",
            .glsl_330 => "330",
            .glsl_400 => "400",
            .glsl_410 => "410",
            .glsl_420 => "420",
            .glsl_430 => "430",
            .glsl_440 => "440",
            else => |e| @tagName(e),
        };
    }

    pub fn addAsArg(profile: Profile, step: *std.Build.Step.Run) void {
        step.addArgs(&.{ "-p", profile.toStr() });
    }

    pub fn appendArg(profile: Profile, alloctor: std.mem.Allocator, args: *ArgsList) !void {
        try args.appendSlice(alloctor, &.{ "-p", profile.toStr() });
    }
};

pub fn createDefaultOptionsForRenderer(renderer: bgfx.RendererType) ShadercOptions {
    return switch (renderer) {
        .Direct3D11 => {
            return .{
                .shaderType = .vertex,
                .profile = .s_5_0,
                .platform = .windows,
            };
        },
        .Direct3D12 => {
            return .{
                .shaderType = .vertex,
                .profile = .s_6_0,
                .platform = .windows,
            };
        },
        .Metal => {
            return .{
                .shaderType = .vertex,
                .profile = .metal,
                .platform = .osx,
            };
        },
        .OpenGLES => {
            return .{
                .shaderType = .vertex,
                .profile = .es_100,
                .platform = .android,
            };
        },
        .OpenGL => {
            return .{
                .shaderType = .vertex,
                .profile = .glsl_120,
                .platform = .linux,
            };
        },
        .Vulkan => {
            return .{
                .shaderType = .vertex,
                .profile = .spirv,
                .platform = .linux,
            };
        },
        else => undefined,
    };
}

pub const ShadercOptions = struct {
    shaderType: ShaderType,

    platform: Platform,
    profile: Profile,

    inputFilePath: ?[]const u8 = null,
    outputFilePath: ?[]const u8 = null,
    varyingFilePath: ?[]const u8 = null,

    includeDirs: ?[]const []const u8 = null,
    defines: ?[]const []const u8 = null,

    optimizationLevel: Optimize = .o3,
    keepcomments: bool = false,
};

pub fn shadercFromExePath(io: std.Io, allocator: std.mem.Allocator) ![]u8 {
    const exe_dir = try std.process.executableDirPathAlloc(io, allocator);
    defer allocator.free(exe_dir);

    const path = try std.fs.path.join(allocator, &.{ exe_dir, "shaderc" });

    if (builtin.os.tag == .windows) {
        return try std.fmt.allocPrint(allocator, "{s}.exe", .{path});
    }

    return path;
}

// Caller is owner of memory.
pub fn compileShader(
    io: std.Io,
    allocator: std.mem.Allocator,
    executable_path: []const u8,
    varying: []const u8,
    shader: []const u8,
    tmp_dir_path: []const u8,
    options: ShadercOptions,
) ![]u8 {
    std.Io.Dir.createDirAbsolute(io, tmp_dir_path, .default_dir) catch |err| {
        if (err != error.PathAlreadyExists) return err;
    };

    // Write source
    var in_random_path: [RANDOM_PATH_LEN]u8 = undefined;
    generateRandomFileName(io, &in_random_path);

    const source_file_path = try std.fs.path.join(allocator, &.{ tmp_dir_path, &in_random_path });
    defer allocator.free(source_file_path);
    const in_f = try std.Io.Dir.createFileAbsolute(io, source_file_path, .{});
    try in_f.writeStreamingAll(io, shader);
    in_f.close(io);
    defer std.Io.Dir.deleteFileAbsolute(io, source_file_path) catch undefined;

    // Write varying
    var varying_random_path: [RANDOM_PATH_LEN]u8 = undefined;
    generateRandomFileName(io, &varying_random_path);

    const varying_file_path = try std.fs.path.join(allocator, &.{ tmp_dir_path, &varying_random_path });
    defer allocator.free(varying_file_path);
    const varying_f = try std.Io.Dir.createFileAbsolute(io, varying_file_path, .{});
    try varying_f.writeStreamingAll(io, varying);
    varying_f.close(io);
    defer std.Io.Dir.deleteFileAbsolute(io, varying_file_path) catch undefined;

    const use_file_output = builtin.os.tag == .windows; // FIXME: Problem only on windows. Load shader in bgfx failed.

    // Create shader output path
    var out_file_path: ?[]u8 = null;
    defer {
        if (out_file_path) |p| allocator.free(p);
    }

    var new_options = options;
    new_options.inputFilePath = source_file_path;
    new_options.varyingFilePath = varying_file_path;

    if (use_file_output) {
        var out_random_path: [RANDOM_PATH_LEN]u8 = undefined;
        generateRandomFileName(io, &out_random_path);
        out_file_path = try std.fs.path.join(allocator, &.{ tmp_dir_path, &out_random_path });
        new_options.outputFilePath = out_file_path;
    }

    var shadercp = try shadercProcess(io, allocator, executable_path, new_options);

    var buffer: [1024]u8 = undefined;
    var reader = shadercp.stdout.?.readerStreaming(io, &buffer);
    var writer = std.Io.Writer.Allocating.init(allocator);
    defer writer.deinit();

    // Read stdout unitl shaderc end.
    while (true) {
        _ = reader.interface.stream(&writer.writer, .unlimited) catch |err| {
            if (err == error.EndOfStream) break else return err;
        };
    }

    const term = try shadercp.wait(io);
    if (term.exited != 0) {
        const out = try writer.toOwnedSlice();
        defer allocator.free(out);
        std.log.err("Shaderc error:\n{s}", .{if (use_file_output) out else out[10..]});
        return error.ShaderCompileError;
    } else {
        if (out_file_path) |output_path| {
            defer std.Io.Dir.deleteFileAbsolute(io, output_path) catch undefined;

            const out_f = try std.Io.Dir.openFileAbsolute(io, output_path, .{ .mode = .read_only });
            defer out_f.close(io);

            const size = try out_f.length(io);
            const data = try allocator.alloc(u8, size);
            _ = try out_f.readPositionalAll(io, data, 0);

            // std.log.debug("BEGIN\n{s}\nEND", .{data});
            return data;
        } else {
            const data = try writer.toOwnedSlice();
            // std.log.debug("BEGIN\n{s}\nEND", .{data});
            return data;
        }
    }
}

pub fn shadercProcess(io: std.Io, allocator: std.mem.Allocator, executablePath: []const u8, options: ShadercOptions) !std.process.Child {
    var args = ArgsList.empty;
    defer args.deinit(allocator);
    try args.append(allocator, executablePath);

    try options.shaderType.appendArg(allocator, &args);
    try options.platform.appendArg(allocator, &args);
    try options.profile.appendArg(allocator, &args);
    try options.optimizationLevel.appendArg(allocator, &args);

    if (options.inputFilePath) |path| {
        try args.appendSlice(allocator, &.{ "-f", path });
    }

    if (options.outputFilePath) |path| {
        try args.appendSlice(allocator, &.{ "-o", path });
    } else {
        try args.appendSlice(allocator, &.{"--stdout"});
    }

    if (options.varyingFilePath) |path| {
        try args.appendSlice(allocator, &.{ "--varyingdef", path });
    }

    if (options.keepcomments) {
        try args.appendSlice(allocator, &.{"--keepcomments"});
    }

    if (options.includeDirs) |includes| {
        for (includes) |include| {
            try args.appendSlice(allocator, &.{ "-i", include });
        }
    }

    var all_defines = std.ArrayList(u8).empty;
    defer all_defines.deinit(allocator);

    if (options.defines) |defines| {
        const last_idx = defines.len - 1;

        for (defines, 0..) |define, idx| {
            try all_defines.appendSlice(allocator, define);
            if (idx != last_idx) {
                try all_defines.appendSlice(allocator, ";");
            }
        }

        try args.appendSlice(allocator, &.{ "--define", all_defines.items });
    }

    const process = std.process.spawn(io, .{
        .argv = args.items,
        .stdout = .pipe,
    });
    return process;
}

const RANDOM_BYTES_COUNT = 12;
const RANDOM_PATH_LEN = std.base64.url_safe.Encoder.calcSize(RANDOM_BYTES_COUNT);

fn generateRandomFileName(io: std.Io, out: []u8) void {
    var in_random_bytes: [RANDOM_BYTES_COUNT]u8 = undefined;
    io.random(&in_random_bytes);
    _ = std.base64.url_safe.Encoder.encode(out, &in_random_bytes);
}
