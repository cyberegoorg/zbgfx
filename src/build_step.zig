const std = @import("std");
const shader = @import("shaderc.zig");

pub fn installShaderc(b: *std.Build, zbgfx_dep: *std.Build.Dependency) !*std.Build.Step {
    var install_shaderc = b.addInstallArtifact(zbgfx_dep.artifact("shaderc"), .{});
    var install_deps = b.addInstallDirectory(.{
        .install_dir = .bin,
        .source_dir = zbgfx_dep.namedWriteFiles("shaderc").getDirectory(),
        .install_subdir = "",
    });

    install_deps.step.dependOn(&install_shaderc.step);

    return &install_deps.step;
}

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
};

pub fn callShaderc(
    b: *std.Build,
    install_shaderc_step: *std.Build.Step,
    options: BuildShaderOptions,
) !BuildShaderC {
    var shaderc_cmd = b.addSystemCommand(&.{b.getInstallPath(.bin, "shaderc")});
    shaderc_cmd.expectStdOutEqual("");

    shaderc_cmd.step.dependOn(install_shaderc_step);

    options.platform.addAsArg(shaderc_cmd);
    options.profile.addAsArg(shaderc_cmd);
    options.shaderType.addAsArg(shaderc_cmd);

    if (options.optimize) |o| {
        o.addAsArg(shaderc_cmd);
    }

    for (options.includes) |include| {
        shaderc_cmd.addArg("-i");
        shaderc_cmd.addDirectoryArg(include);
    }

    shaderc_cmd.addArg("-f");
    shaderc_cmd.addFileArg(options.input);
    shaderc_cmd.addArg("-o");
    const compiled_shader = shaderc_cmd.addOutputFileArg("shader.bin");

    return .{ .cmd = shaderc_cmd, .output = compiled_shader };
}

pub fn combineShaderPartsStep(
    b: *std.Build,
    output_name: []const u8,
    combine_shader_parts: *std.Build.Step.Compile,
    parts: [][]const u8,
) std.Build.LazyPath {
    const run = b.addRunArtifact(combine_shader_parts);
    const final = run.addOutputFileArg(output_name);
    run.addArgs(parts);
    return final;
}

pub fn combineShadersStep(
    b: *std.Build,
    output_name: []const u8,
    combine_shaders: *std.Build.Step.Compile,
    parts: [][]const u8,
) std.Build.LazyPath {
    const run = b.addRunArtifact(combine_shaders);
    const final = run.addOutputFileArg(output_name);
    run.addArgs(parts);
    return final;
}

pub const PartDef = struct {
    profile: shader.Profile,
    platform: shader.Platform,
    optimize: ?shader.Optimize = null,
};

pub const ShaderInput = struct {
    name: []const u8,
    shaderType: shader.ShaderType,
    path: std.Build.LazyPath,
    parts: []const PartDef = &.{
        .{ .profile = .glsl_120, .platform = .linux },
        .{ .profile = .es_100, .platform = .android },
        .{ .profile = .spirv, .platform = .linux },
        .{ .profile = .metal, .platform = .osx, .optimize = .o3 },
        .{ .profile = .s_5_0, .platform = .windows, .optimize = .o3 },
        .{ .profile = .s_6_0, .platform = .windows, .optimize = .o3 },
    },
};

pub fn compileShaders(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    install_shaderc_step: *std.Build.Step,
    zbgfx_dep: *std.Build.Dependency,
    includes: []const std.Build.LazyPath,
    shaders: []const ShaderInput,
) !*std.Build.Module {
    var shaders_module = b.createModule(.{});

    var names = try std.ArrayList([]const u8).initCapacity(b.allocator, shaders.len);
    defer names.deinit(b.allocator);

    for (shaders) |sh| {
        names.appendAssumeCapacity(sh.name);

        const module = try compileShader(
            b,
            target,
            install_shaderc_step,
            zbgfx_dep,
            includes,
            sh,
        );
        shaders_module.addImport(sh.name, module);
    }

    const combine_shaders = zbgfx_dep.artifact("combine_shaders");
    const combine_step = combineShadersStep(
        b,
        "module.zig",
        combine_shaders,
        names.items,
    );

    shaders_module.root_source_file = combine_step;

    return shaders_module;
}

pub fn profileToPartName(profile: shader.Profile) []const u8 {
    return switch (profile) {
        .es_100,
        .es_300,
        .es_310,
        .es_320,
        => "essl",

        .s_4_0,
        .s_5_0,
        => "dx11",

        .s_6_0,
        .s_6_1,
        .s_6_2,
        .s_6_3,
        .s_6_4,
        .s_6_5,
        .s_6_6,
        .s_6_7,
        .s_6_8,
        .s_6_9,
        => "dxil",

        .metal,
        .metal10_10,
        .metal11_10,
        .metal12_10,
        .metal20_11,
        .metal21_11,
        .metal22_11,
        .metal23_14,
        .metal24_14,
        .metal30_14,
        .metal31_14,
        => "mtl",

        .pssl => "pssl",

        .spirv,
        .spirv10_10,
        .spirv13_11,
        .spirv14_11,
        .spirv15_12,
        .spirv16_13,
        => "spv",

        .glsl_120,
        .glsl_130,
        .glsl_140,
        .glsl_150,
        .glsl_330,
        .glsl_400,
        .glsl_410,
        .glsl_420,
        .glsl_430,
        .glsl_440,
        => "glsl",
    };
}

// TODO: Compile only valid shaders for target. (ex.: dx for linux target, but compile dx for windows on linux is valid)
pub fn compileShader(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    install_shaderc_step: *std.Build.Step,
    zbgfx_dep: *std.Build.Dependency,
    includes: []const std.Build.LazyPath,
    input: ShaderInput,
) !*std.Build.Module {
    const combine_shader_parts = zbgfx_dep.artifact("combine_shader_parts");
    const zbgfx_module = zbgfx_dep.module("zbgfx");

    var shaders = std.ArrayList(std.Build.LazyPath){};
    defer shaders.deinit(b.allocator);

    try compileShaderVariants(
        b,
        &shaders,
        target,
        install_shaderc_step,
        includes,
        input,
    );

    var parts = std.ArrayList([]const u8){};
    defer parts.deinit(b.allocator);
    var shaders_module = b.createModule(.{
        .imports = &.{
            .{ .name = "zbgfx", .module = zbgfx_module },
        },
    });

    for (input.parts, 0..) |part, idx| {
        if (target.result.os.tag != .windows and part.profile == .s_5_0) continue;
        if (target.result.os.tag != .windows and part.profile == .s_6_0) continue;

        const part_name = profileToPartName(part.profile);
        shaders_module.addAnonymousImport(part_name, .{ .root_source_file = shaders.items[idx] });
        try parts.append(b.allocator, part_name);
    }

    const basename = try std.fmt.allocPrint(b.allocator, "{s}.zig", .{input.name});
    defer b.allocator.free(basename);

    const combine_step = combineShaderPartsStep(
        b,
        basename,
        combine_shader_parts,
        parts.items,
    );

    shaders_module.root_source_file = combine_step;

    return shaders_module;
}

const LazyPathList = std.ArrayList(std.Build.LazyPath);
pub fn compileShaderVariants(
    b: *std.Build,
    out_shaders: *LazyPathList,
    target: std.Build.ResolvedTarget,
    install_shaderc_step: *std.Build.Step,
    includes: []const std.Build.LazyPath,
    input: ShaderInput,
) !void {
    for (input.parts) |part| {
        if (target.result.os.tag != .windows and part.profile == .s_5_0) continue;
        if (target.result.os.tag != .windows and part.profile == .s_6_0) continue;

        const shader_build = try callShaderc(
            b,
            install_shaderc_step,
            .{
                .shaderType = input.shaderType,
                .platform = part.platform,
                .optimize = part.optimize,
                .profile = part.profile,
                .input = input.path,
                .output = "shaders.zig",
                .includes = includes,
            },
        );
        try out_shaders.append(b.allocator, shader_build.output);
    }
}
