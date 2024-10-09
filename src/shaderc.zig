const std = @import("std");
const builtin = @import("builtin");

const bgfx = @import("bgfx.zig");

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

    pub fn appendArg(t: ShaderType, args: *ArgsList) !void {
        try args.appendSlice(&.{ "--type", t.toStr() });
    }
};

pub const Optimize = enum(u32) {
    o1 = 1,
    o2 = 2,
    o3 = 3,

    pub fn toStr(optimize: Optimize) [:0]const u8 {
        return switch (optimize) {
            .o1 => "1",
            .o2 => "2",
            .o3 => "3",
        };
    }

    pub fn addAsArg(t: Optimize, step: *std.Build.Step.Run) void {
        step.addArgs(&.{ "-O", t.toStr() });
    }

    pub fn appendArg(t: Optimize, args: *ArgsList) !void {
        try args.appendSlice(&.{ "-O", t.toStr() });
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

    pub fn appendArg(platform: Platform, args: *ArgsList) !void {
        try args.appendSlice(&.{ "--platform", platform.toStr() });
    }
};

pub const Profile = enum {
    es_100,
    es_300,
    es_310,
    es_320,

    s_4_0,
    s_5_0,

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

    pub fn appendArg(profile: Profile, args: *ArgsList) !void {
        try args.appendSlice(&.{ "-p", profile.toStr() });
    }
};

pub fn createDefaultOptionsForRenderer(renderer: bgfx.RendererType) ShadercOptions {
    return switch (renderer) {
        .Direct3D11 => {
            return .{
                .shaderType = .vertex,
                .profile = .s_4_0,
                .platform = .windows,
            };
        },
        .Direct3D12 => {
            return .{
                .shaderType = .vertex,
                .profile = .s_5_0,
                .platform = .windows,
            };
        },
        .Metal => {
            return .{
                .shaderType = .vertex,
                .profile = .metal,
                .platform = .ios,
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
};

pub fn shadercFromExePath(allocator: std.mem.Allocator) ![]u8 {
    const exe_dir = try std.fs.selfExeDirPathAlloc(allocator);
    defer allocator.free(exe_dir);

    const path = try std.fs.path.join(allocator, &.{ exe_dir, "shaderc" });

    if (builtin.os.tag == .windows) {
        return try std.fmt.allocPrint(allocator, "{s}.exe", .{path});
    }

    return path;
}

// Caller is owner of memory.
pub fn compileShader(
    allocator: std.mem.Allocator,
    executable_path: []const u8,
    varying: []const u8,
    shader: []const u8,
    options: ShadercOptions,
) ![]u8 {
    const system_tmp_dir_path = try getSysTmpDir(allocator);
    defer allocator.free(system_tmp_dir_path);

    const tmp_dir_path = try std.fs.path.join(allocator, &.{ system_tmp_dir_path, "shaderc" });
    defer allocator.free(tmp_dir_path);

    std.fs.makeDirAbsolute(tmp_dir_path) catch |err| {
        if (err != error.PathAlreadyExists) return err;
    };

    // Write source
    var in_random_path: [RANDOM_PATH_LEN]u8 = undefined;
    generateRandomFileName(&in_random_path);

    const source_file_path = try std.fs.path.join(allocator, &.{ tmp_dir_path, &in_random_path });
    defer allocator.free(source_file_path);
    const in_f = try std.fs.createFileAbsolute(source_file_path, .{});
    try in_f.writeAll(shader);
    in_f.close();
    defer std.fs.deleteFileAbsolute(source_file_path) catch undefined;

    // Write varying
    var varying_random_path: [RANDOM_PATH_LEN]u8 = undefined;
    generateRandomFileName(&varying_random_path);

    const varying_file_path = try std.fs.path.join(allocator, &.{ tmp_dir_path, &varying_random_path });
    defer allocator.free(varying_file_path);
    const varying_f = try std.fs.createFileAbsolute(varying_file_path, .{});
    try varying_f.writeAll(varying);
    varying_f.close();

    defer std.fs.deleteFileAbsolute(varying_file_path) catch undefined;

    // Create shader output path
    var out_random_path: [RANDOM_PATH_LEN]u8 = undefined;
    generateRandomFileName(&out_random_path);
    const out_file_path = try std.fs.path.join(allocator, &.{ tmp_dir_path, &out_random_path });
    defer allocator.free(out_file_path);

    var new_options = options;
    new_options.inputFilePath = source_file_path;
    new_options.varyingFilePath = varying_file_path;
    new_options.outputFilePath = out_file_path;

    var shadercp = try shadercProcess(allocator, executable_path, new_options);
    const term = try shadercp.wait();
    if (term.Exited != 0) return error.ShaderCompileError;

    defer std.fs.deleteFileAbsolute(out_file_path) catch undefined;

    const out_f = try std.fs.openFileAbsolute(out_file_path, .{ .mode = .read_only });
    defer out_f.close();

    const size = try out_f.getEndPos();
    const shader_data = try allocator.alloc(u8, size);
    _ = try out_f.readAll(shader_data);

    return shader_data;
}

pub fn shadercProcess(allocator: std.mem.Allocator, executablePath: []const u8, options: ShadercOptions) !std.process.Child {
    var args = ArgsList.init(allocator);
    defer args.deinit();
    try args.append(executablePath);

    try options.shaderType.appendArg(&args);
    try options.platform.appendArg(&args);
    try options.profile.appendArg(&args);
    try options.optimizationLevel.appendArg(&args);

    if (options.inputFilePath) |path| {
        try args.appendSlice(&.{ "-f", path });
    }

    if (options.outputFilePath) |path| {
        try args.appendSlice(&.{ "-o", path });
    }

    if (options.varyingFilePath) |path| {
        try args.appendSlice(&.{ "--varyingdef", path });
    }

    if (options.includeDirs) |includes| {
        for (includes) |include| {
            try args.appendSlice(&.{ "-i", include });
        }
    }

    var all_defines = std.ArrayList(u8).init(allocator);
    defer all_defines.deinit();

    if (options.defines) |defines| {
        const last_idx = defines.len - 1;

        for (defines, 0..) |define, idx| {
            try all_defines.appendSlice(define);
            if (idx != last_idx) {
                try all_defines.appendSlice(";");
            }
        }

        try args.appendSlice(&.{ "--define", all_defines.items });
    }

    var process = std.process.Child.init(args.items, allocator);
    try process.spawn();
    return process;
}

const RANDOM_BYTES_COUNT = 12;
const RANDOM_PATH_LEN = std.fs.base64_encoder.calcSize(RANDOM_BYTES_COUNT);

fn generateRandomFileName(out: []u8) void {
    var in_random_bytes: [RANDOM_BYTES_COUNT]u8 = undefined;
    std.crypto.random.bytes(&in_random_bytes);
    _ = std.fs.base64_encoder.encode(out, &in_random_bytes);
}

// https://github.com/liyu1981/tmpfile.zig/blob/master/src/tmpfile.zig#L11
fn getSysTmpDir(a: std.mem.Allocator) ![]const u8 {
    const Impl = switch (builtin.os.tag) {
        .linux, .macos => struct {
            pub fn get(allocator: std.mem.Allocator) ![]const u8 {
                // cpp17's temp_directory_path gives good reference
                // https://en.cppreference.com/w/cpp/filesystem/temp_directory_path
                // POSIX standard, https://en.wikipedia.org/wiki/TMPDIR
                return std.process.getEnvVarOwned(allocator, "TMPDIR") catch {
                    return std.process.getEnvVarOwned(allocator, "TMP") catch {
                        return std.process.getEnvVarOwned(allocator, "TEMP") catch {
                            return std.process.getEnvVarOwned(allocator, "TEMPDIR") catch {
                                std.debug.print("tried env TMPDIR/TMP/TEMP/TEMPDIR but not found, fallback to /tmp, caution it may not work!", .{});
                                return try allocator.dupe(u8, "/tmp");
                            };
                        };
                    };
                };
            }
        },
        .windows => struct {
            const DWORD = std.os.windows.DWORD;
            const LPWSTR = std.os.windows.LPWSTR;
            const MAX_PATH = std.os.windows.MAX_PATH;
            const WCHAR = std.os.windows.WCHAR;

            pub extern "C" fn GetTempPath2W(BufferLength: DWORD, Buffer: LPWSTR) DWORD;

            pub fn get(allocator: std.mem.Allocator) ![]const u8 {
                // use GetTempPathW2, https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-gettemppathw
                var wchar_buf: [MAX_PATH + 2:0]WCHAR = undefined;
                wchar_buf[MAX_PATH + 1] = 0;
                const ret = GetTempPath2W(MAX_PATH + 1, &wchar_buf);
                if (ret != 0) {
                    const path = wchar_buf[0..ret];
                    return std.unicode.utf16LeToUtf8Alloc(allocator, path);
                } else {
                    return error.GetTempPath2WFailed;
                }
            }
        },
        else => {
            @panic(@tagName(std.builtin.os.tag) ++ " is not support");
        },
    };

    return Impl.get(a);
}
