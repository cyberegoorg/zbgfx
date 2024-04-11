const std = @import("std");

pub const ShaderType = enum {
    vertex,
    fragment,
    compute,

    pub fn toStr(t: ShaderType) []const u8 {
        return @tagName(t);
    }

    pub fn addAsArg(t: ShaderType, step: *std.Build.Step.Run) void {
        step.addArgs(&.{ "--type", t.toStr() });
    }
};

pub const Optimize = enum {
    o1,
    o2,
    o3,

    pub fn toStr(optimize: Optimize) []const u8 {
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

    pub fn toStr(platform: Platform) []const u8 {
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

    pub fn toStr(profile: Profile) []const u8 {
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
