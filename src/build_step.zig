const std = @import("std");
const shader = @import("shaderc.zig");

pub const BuildShaderC = struct {
    cmd: *std.Build.Step.Run,
    output: std.Build.LazyPath,
};

pub const BuildShaderOptions = struct {
    input: std.Build.LazyPath,
    output: []const u8,
    includes: []const std.Build.LazyPath,
    shaderType: shader.ShaderType,
    platform: shader.Platform,
    profile: shader.Profile,
    optimize: ?shader.Optimize,
    bin2c: ?[]const u8,
};

pub fn profileToPostfix(profile: shader.Profile) []const u8 {
    return switch (profile) {
        .metal => "mtl",
        .s_5_0 => "dx11",
        .spirv => "spv",
        .es_100 => "essl",
        .glsl_120 => "glsl",
        else => undefined,
    };
}

pub fn buildShaderC(
    b: *std.Build,
    shaderc: *std.Build.Step.Compile,
    options: BuildShaderOptions,
) !BuildShaderC {
    const shaderc_cmd = b.addRunArtifact(shaderc);

    options.platform.addAsArg(shaderc_cmd);
    options.profile.addAsArg(shaderc_cmd);
    options.shaderType.addAsArg(shaderc_cmd);

    if (options.optimize) |o| {
        o.addAsArg(shaderc_cmd);
    }

    if (options.bin2c) |array_name| {
        const postfix = profileToPostfix(options.profile);

        var buff: [256]u8 = undefined;
        const bin2c = try std.fmt.bufPrint(&buff, "{s}_{s}", .{ array_name, postfix });

        shaderc_cmd.addArgs(&.{ "--bin2c", bin2c });
    }

    for (options.includes) |include| {
        shaderc_cmd.addArg("-i");
        shaderc_cmd.addDirectoryArg(include);
    }

    shaderc_cmd.addArg("-f");
    shaderc_cmd.addFileArg(options.input);

    shaderc_cmd.addArg("-o");
    const compiled_shader = shaderc_cmd.addOutputFileArg(options.output);

    return .{ .cmd = shaderc_cmd, .output = compiled_shader };
}

pub const CombineBinZigOptions = struct {
    parts: [][]const u8,
    output: []const u8,
};

pub fn combineBinZigStep(
    b: *std.Build,
    output_name: []const u8,
    combine_bin_zig: *std.Build.Step.Compile,
    options: CombineBinZigOptions,
) std.Build.LazyPath {
    const run = b.addRunArtifact(combine_bin_zig);
    const final_h = run.addOutputFileArg(output_name);
    run.addArgs(options.parts);
    return final_h;
}

pub const CombineBinHOptions = struct {
    shader_name: []const u8,
    parts: []const std.Build.LazyPath,
    output: []const u8,
};

pub fn combineBinHStep(
    b: *std.Build,
    combine_bin_h: *std.Build.Step.Compile,
    options: CombineBinHOptions,
) *std.Build.Step {
    const run = b.addRunArtifact(combine_bin_h);
    run.addArg(options.shader_name);
    const final_h = run.addOutputFileArg("final.bin.h");

    for (options.parts) |path| {
        run.addFileArg(path);
    }

    const wf = b.addUpdateSourceFiles();
    wf.addCopyFileToSource(final_h, options.output);

    return &wf.step;
}

pub const BasicCompileInput = struct {
    input: std.Build.LazyPath,
    shaderType: shader.ShaderType,
};

pub const BasicCompileOptions = struct {
    output: []const u8,
    bin2c: ?[]const u8 = null,
    includes: []const std.Build.LazyPath,
};

pub fn compileBasicBinZig(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    shaderc: *std.Build.Step.Compile,
    zbgfx_modul: *std.Build.Module,
    combine_zig_h: *std.Build.Step.Compile,
    shader_zig_name: []const u8,
    input: BasicCompileInput,
    options: BasicCompileOptions,
) !*std.Build.Module {
    var shaders = std.ArrayList(std.Build.LazyPath){};
    defer shaders.deinit(b.allocator);

    try compileBasic(
        b,
        &shaders,
        target,
        shaderc,
        input,
        options,
    );

    var variants = std.ArrayList([]const u8){};
    defer variants.deinit(b.allocator);

    var shaders_module = b.createModule(.{
        .imports = &.{
            .{ .name = "zbgfx", .module = zbgfx_modul },
        },
    });

    for (basic_profiles, 0..) |profile, idx| {
        if (target.result.os.tag != .windows and profile == .s_5_0) continue;
        const variant_name = profileToPostfix(profile);
        shaders_module.addAnonymousImport(variant_name, .{ .root_source_file = shaders.items[idx] });
        try variants.append(b.allocator, variant_name);
    }

    const combine_step = combineBinZigStep(
        b,
        shader_zig_name,
        combine_zig_h,
        .{
            .output = options.output,
            .parts = variants.items,
        },
    );

    shaders_module.root_source_file = combine_step;

    return shaders_module;
}

pub fn compileBasicBinH(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    shaderc: *std.Build.Step.Compile,
    combine_bin_h: *std.Build.Step.Compile,
    input: BasicCompileInput,
    options: BasicCompileOptions,
) !*std.Build.Step {
    var shaders = std.ArrayList(std.Build.LazyPath){};
    defer shaders.deinit(b.allocator);

    try compileBasic(
        b,
        &shaders,
        target,
        shaderc,
        input,
        options,
    );

    const combine_step = combineBinHStep(b, combine_bin_h, .{
        .output = options.output,
        .parts = shaders.items,
        .shader_name = options.bin2c.?,
    });

    return combine_step;
}

// Basic build use these to map it to platform
const basic_profiles = [_]shader.Profile{
    .glsl_120,
    .es_100,
    .spirv,
    .metal,
    .s_5_0,
};

const LazyPathList = std.ArrayList(std.Build.LazyPath);
pub fn compileBasic(
    b: *std.Build,
    out_shaders: *LazyPathList,
    target: std.Build.ResolvedTarget,
    shaderc: *std.Build.Step.Compile,
    input: BasicCompileInput,
    options: BasicCompileOptions,
) !void {
    for (basic_profiles) |profile| {
        if (target.result.os.tag != .windows and profile == .s_5_0) continue;

        const optimize: ?shader.Optimize = switch (profile) {
            .s_5_0 => .o3,
            .metal => .o3,
            else => null,
        };

        const os: shader.Platform = switch (profile) {
            .glsl_120 => .linux,
            .spirv => .linux,
            .s_5_0 => .windows,
            .metal => .ios,
            .es_100 => .android,
            else => undefined,
        };

        const shader_build = try buildShaderC(
            b,
            shaderc,
            .{
                .shaderType = input.shaderType,
                .platform = os,
                .optimize = optimize,
                .profile = profile,
                .bin2c = options.bin2c,
                .input = input.input,
                .output = "shader.bin.h",
                .includes = options.includes,
            },
        );
        try out_shaders.append(b.allocator, shader_build.output);
    }
}
