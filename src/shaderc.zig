const std = @import("std");
const bgfx = @import("bgfx.zig");

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

// TEMP SHIT
const ShaderOutput = std.ArrayList(u8);
const ShaderWriter = struct {
    pub fn write(ctx: *anyopaque, _data: [*]const u8, _size: i32) callconv(.C) i32 {
        var shader_out: *ShaderOutput = @alignCast(@ptrCast(ctx));
        shader_out.appendSlice(_data[0..@intCast(_size)]) catch undefined;
        return _size;
    }
};

const MessageWriter = struct {
    pub fn write(ctx: *anyopaque, _data: [*]const u8, _size: i32) callconv(.C) i32 {
        _ = ctx; // autofix
        const result = std.io.getStdOut().write(_data[0..@intCast(_size)]) catch undefined;
        return @intCast(result);
    }
};

pub const ShadercOptions = struct {
    shaderType: ShaderType,

    platform: Platform,
    profile: Profile,
    inputFilePath: ?[:0]const u8 = null,
    outputFilePath: ?[:0]const u8 = null,
    includeDirs: ?[][:0]const u8 = null,
    defines: ?[][:0]const u8 = null,
    dependencies: ?[][:0]const u8 = null,

    disasm: bool = false,
    raw: bool = false,
    preprocessOnly: bool = false,
    depends: bool = false,
    debugInformation: bool = false,
    avoidFlowControl: bool = false,
    noPreshader: bool = false,
    partialPrecision: bool = false,
    preferFlowControl: bool = false,
    backwardsCompatibility: bool = false,
    warningsAreErrors: bool = false,
    keepIntermediate: bool = false,
    optimize: bool = false,
    optimizationLevel: Optimize = .o3,

    pub fn toCOptions(options: ShadercOptions) COptions {
        return COptions{
            .shaderType = options.shaderType.toChar(),
            .platform = options.platform.toStr(),
            .profile = options.profile.toStr(),
            .inputFilePath = options.inputFilePath orelse "embed",
            .outputFilePath = options.outputFilePath orelse "embed",

            .includeDirs = if (options.includeDirs) |i| @ptrCast(i.ptr) else null,
            .includeDirsN = if (options.includeDirs) |i| @intCast(i.len) else 0,

            .defines = if (options.defines) |i| @ptrCast(i.ptr) else null,
            .definesN = if (options.defines) |i| @intCast(i.len) else 0,

            .dependencies = if (options.dependencies) |i| @ptrCast(i.ptr) else null,
            .dependenciesN = if (options.dependencies) |i| @intCast(i.len) else 0,

            .disasm = options.disasm,
            .raw = options.raw,
            .preprocessOnly = options.preprocessOnly,
            .depends = options.depends,
            .debugInformation = options.debugInformation,
            .avoidFlowControl = options.avoidFlowControl,
            .noPreshader = options.noPreshader,
            .partialPrecision = options.partialPrecision,
            .preferFlowControl = options.preferFlowControl,
            .backwardsCompatibility = options.backwardsCompatibility,
            .warningsAreErrors = options.warningsAreErrors,
            .keepIntermediate = options.keepIntermediate,
            .optimize = options.optimize,
            .optimizationLevel = @intFromEnum(options.optimizationLevel),
        };
    }
};

// Caller is owner of memory.
pub fn compileShader(allocator: std.mem.Allocator, varying: [:0]const u8, shader: []const u8, options: ShadercOptions) ![]u8 {
    var wirteMsg = MessageWriter{};

    // +16384  is from shaderc.cpp
    const data = try allocator.alloc(u8, shader.len + 16384);
    @memset(data, 0);
    defer allocator.free(data);

    var fbs = std.io.fixedBufferStream(data);
    const len = try fbs.write(shader);

    // Shaderc at the end do delete [] data.
    // We need allocate it with malloc.
    var data2: [*]u8 = @ptrCast(std.c.malloc(data.len).?);
    std.mem.copyBackwards(u8, data2[0..data.len], data);

    var out = ShaderOutput.init(allocator);
    errdefer out.deinit();

    const coptions = options.toCOptions();

    const shader_result = zbgfx_compileShader(
        varying.ptr,
        "",
        data2,
        @intCast(len),
        &coptions,
        ShaderWriter.write,
        &out,
        MessageWriter.write,
        &wirteMsg,
    );

    if (!shader_result) {
        return error.ShaderCompileFail;
    }

    return out.toOwnedSlice();
}

pub const COptions = extern struct {
    shaderType: u8 = ' ',

    platform: [*c]const u8,
    profile: [*c]const u8,

    inputFilePath: [*c]const u8,
    outputFilePath: [*c]const u8,

    includeDirs: ?[*][*c]const u8,
    includeDirsN: u32,

    defines: ?[*][*c]const u8,
    definesN: u32,

    dependencies: ?[*][*c]const u8,
    dependenciesN: u32,

    disasm: bool = false,
    raw: bool = false,
    preprocessOnly: bool = false,
    depends: bool = false,
    debugInformation: bool = false,
    avoidFlowControl: bool = false,
    noPreshader: bool = false,
    partialPrecision: bool = false,
    preferFlowControl: bool = false,
    backwardsCompatibility: bool = false,
    warningsAreErrors: bool = false,
    keepIntermediate: bool = false,
    optimize: bool = false,
    optimizationLevel: u32 = 3,
};
pub const writeFce = *const fn (ctx: *anyopaque, _data: [*]const u8, _size: i32) callconv(.C) i32;
pub extern fn zbgfx_compileShader(
    _varying: [*]const u8,
    _comment: [*]const u8,
    _shader: [*]const u8,
    _shaderLen: u32,
    _options: *const COptions,
    _shaderWriter: writeFce,
    _shaderWriterContext: *anyopaque,
    _messageWriter: writeFce,
    _messageWriterContext: *anyopaque,
) bool;

pub extern fn shaderc_main(_argc: c_int, _argv: [*c][*:0]const u8) c_int;
