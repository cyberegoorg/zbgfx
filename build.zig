const std = @import("std");
const zbgfx = @import("src/zbgfx.zig");

pub const build_shader = zbgfx.build;

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    //
    // OPTIONS
    //

    const options = .{
        .imgui_include = b.option([]const u8, "imgui_include", "Path to imgui (need for imgui bgfx backend)"),
        .multithread = b.option(bool, "multithread", "Compile with BGFX_CONFIG_MULTITHREADED") orelse true,
        .with_shaderc = b.option(bool, "with_shaderc", "Compile with shaderc executable") orelse true,
    };

    const options_step = b.addOptions();
    inline for (std.meta.fields(@TypeOf(options))) |field| {
        options_step.addOption(field.type, field.name, @field(options, field.name));
    }
    const options_module = options_step.createModule();
    _ = options_module; // autofix

    //
    // Compile imgui shaders for embeding in C++
    // WARNING: HLSL only on windows.
    // But dont worry be hapy because compiled shaders are in repo :tada:
    //
    const compile_imgui_shaders = b.step("compile-imgui-shaders", "Compile shaders for ImGui backend");

    const common_options = [_][]const u8{
        "-fno-sanitize=undefined", // Spentime... 3 fucking days... and randomly found this https://ruoyusun.com/2022/02/27/zig-cc.html (Thx ;))
        "-fno-strict-aliasing",
        "-fno-exceptions",
        "-fno-rtti",
        "-ffast-math",
        // "-fomit-frame-pointer",

        "-Wno-microsoft-enum-value",
        "-Wno-microsoft-const-init",
        "-Wno-deprecated-declarations",
        "-Wno-tautological-constant-compare",
        "-Wno-error=date-time",
        "-Wno-error=unused-command-line-argument",
    };
    const cxx_options = common_options ++ [_][]const u8{
        "-std=c++20",
    };
    const c_options = common_options ++ [_][]const u8{};
    const mm_options = cxx_options ++ [_][]const u8{};

    //
    // Tools
    //
    const combine_bin_h = b.addExecutable(.{
        .name = "combine_bin_h",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/combine_bin_h.zig"),
            .target = target,
            .optimize = optimize,
        }),
        .use_llvm = true,
    });
    const combine_bin_zig = b.addExecutable(.{
        .name = "combine_bin_zig",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/combine_bin_zig.zig"),
            .target = target,
            .optimize = optimize,
        }),
        .use_llvm = true,
    });

    b.installArtifact(combine_bin_zig);

    //
    // Bx
    //
    const bx = b.addLibrary(.{
        .linkage = .static,
        .name = "bx",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
        .use_llvm = true,
    });
    bx.addCSourceFiles(.{
        .flags = &cxx_options,
        .files = &[_][]const u8{
            "libs/bx/src/amalgamated.cpp",
        },
    });
    bxInclude(b, bx, target, optimize);
    bx.linkLibCpp();
    bx.linkLibC();

    //
    // Bimg
    //
    const bimg = b.addLibrary(.{
        .linkage = .static,
        .name = "bimg",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
        .use_llvm = true,
    });
    bimg.addCSourceFiles(.{
        .flags = &cxx_options,
        .files = &bimg_files,
    });

    bimg.addCSourceFiles(.{
        .flags = &c_options,
        .files = &[_][]const u8{
            "libs/bimg/3rdparty/tinyexr/deps/miniz/miniz.c",
        },
    });
    bxInclude(b, bimg, target, optimize);
    bimgInclude(b, bimg);
    bimg.linkLibCpp();

    //
    // Bgfx
    //
    const bgfx_path = "libs/bgfx/";
    const bgfx = b.addLibrary(.{
        .linkage = .static,
        .name = "bgfx",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
        .use_llvm = true,
    });
    b.installArtifact(bgfx);
    bxInclude(b, bgfx, target, optimize);
    bgfxInclude(b, bgfx, target);
    bimgInclude(b, bgfx);

    bgfx.linkLibCpp();
    bgfx.linkLibrary(bx);
    bgfx.linkLibrary(bimg);

    bgfx.root_module.addCMacro("BGFX_CONFIG_MULTITHREADED", if (options.multithread) "1" else "0");

    bgfx.addIncludePath(b.path("includes"));

    if (target.result.isDarwinLibC()) {
        bgfx.linkSystemLibrary("objc");

        bgfx.linkFramework("Cocoa");
        bgfx.linkFramework("IOKit");
        bgfx.linkFramework("OpenGL");
        bgfx.linkFramework("QuartzCore");
        bgfx.linkFramework("Metal");
        bgfx.linkFramework("MetalKit");

        bgfx.addCSourceFiles(.{
            .flags = &mm_options,
            .files = &[_][]const u8{
                "libs/bgfx/src/amalgamated.mm",
            },
        });
    } else {
        bgfx.addCSourceFiles(.{
            .flags = &cxx_options,
            .files = &[_][]const u8{
                "libs/bgfx/src/amalgamated.cpp",
            },
        });
    }

    // utils and another stuff
    bgfx.addCSourceFiles(.{
        .flags = &cxx_options,
        .files = &[_][]const u8{
            "src/zbgfx.cpp",
        },
    });

    // debugdraw
    bgfx.addCSourceFiles(.{
        .flags = &cxx_options,
        .files = &[_][]const u8{
            "libs/bgfx/examples/common/debugdraw/debugdraw.cpp",
        },
    });

    //
    // Bgfx imgui backend
    // TODO: zig based
    //
    const bgfx_imgui_path = "libs/bgfx/examples/common/imgui/";
    if (options.imgui_include) |include| {
        bgfx.addIncludePath(.{ .cwd_relative = include });
        bgfx.addCSourceFiles(.{
            .flags = &cxx_options,
            .files = &[_][]const u8{
                bgfx_imgui_path ++ "imgui.cpp",
            },
        });
    }

    const zbgfx_module = b.addModule("zbgfx", .{
        .root_source_file = b.path("src/zbgfx.zig"),
    });
    _ = zbgfx_module; // autofix

    //
    // Shaderc
    // Base steal from https://github.com/Interrupt/zig-bgfx-example/blob/main/build_shader_compiler.zig
    //
    if (options.with_shaderc) {
        //
        // Shaderc executable
        //
        const shaderc = b.addExecutable(.{
            .name = "shaderc",
            .root_module = b.createModule(.{
                .target = target,
                .optimize = optimize,
            }),
            .use_llvm = true,
        });

        b.installArtifact(shaderc);

        if (target.result.os.tag.isDarwin()) {
            shaderc.linkFramework("CoreFoundation");
            shaderc.linkFramework("Foundation");
        }
        shaderc.linkLibrary(bx);
        shaderc.linkLibCpp();

        bxInclude(b, shaderc, target, optimize);

        shaderc.addIncludePath(b.path("libs/bimg/include"));
        shaderc.addIncludePath(b.path(bgfx_path ++ "include"));
        shaderc.addIncludePath(b.path(bgfx_path ++ "src"));
        shaderc.addIncludePath(b.path(bgfx_path ++ "3rdparty/dxsdk/include"));
        shaderc.addIncludePath(b.path(bgfx_path ++ "3rdparty/fcpp"));
        shaderc.addIncludePath(b.path(bgfx_path ++ "3rdparty/glslang/glslang/Public"));
        shaderc.addIncludePath(b.path(bgfx_path ++ "3rdparty/glslang/glslang/Include"));
        shaderc.addIncludePath(b.path(bgfx_path ++ "3rdparty/glslang"));
        shaderc.addIncludePath(b.path(bgfx_path ++ "3rdparty/glsl-optimizer/include"));
        shaderc.addIncludePath(b.path(bgfx_path ++ "3rdparty/glsl-optimizer/src/glsl"));
        shaderc.addIncludePath(b.path(bgfx_path ++ "3rdparty/spirv-cross"));
        shaderc.addIncludePath(b.path(bgfx_path ++ "3rdparty/spirv-tools/include"));
        shaderc.addIncludePath(b.path(bgfx_path ++ "3rdparty/webgpu/include"));

        shaderc.addCSourceFiles(.{
            .files = &.{
                bgfx_path ++ "src/shader.cpp",
                bgfx_path ++ "src/shader_dxbc.cpp",
                bgfx_path ++ "src/shader_spirv.cpp",
                bgfx_path ++ "src/vertexlayout.cpp",
                bgfx_path ++ "tools/shaderc/shaderc.cpp",
                bgfx_path ++ "tools/shaderc/shaderc_glsl.cpp",
                bgfx_path ++ "tools/shaderc/shaderc_hlsl.cpp",
                bgfx_path ++ "tools/shaderc/shaderc_metal.cpp",
                bgfx_path ++ "tools/shaderc/shaderc_pssl.cpp",
                bgfx_path ++ "tools/shaderc/shaderc_spirv.cpp",
            },
            .flags = &cxx_options,
        });

        //
        // Imgui .bin.h shader embeding step.
        //
        const shader_includes = b.path("shaders");
        const fs_imgui_image_bin_h = try zbgfx.build.compileBasicBinH(
            b,
            target,
            shaderc,
            combine_bin_h,
            .{
                .shaderType = .fragment,
                .input = b.path(bgfx_imgui_path ++ "fs_imgui_image.sc"),
            },
            .{
                .bin2c = "fs_imgui_image",
                .output = bgfx_imgui_path ++ "fs_imgui_image.bin.h",
                .includes = &.{shader_includes},
            },
        );

        //
        const fs_ocornut_imgui_bin_h = try zbgfx.build.compileBasicBinH(
            b,
            target,
            shaderc,
            combine_bin_h,
            .{
                .shaderType = .fragment,
                .input = b.path(bgfx_imgui_path ++ "fs_ocornut_imgui.sc"),
            },
            .{
                .bin2c = "fs_ocornut_imgui",
                .output = bgfx_imgui_path ++ "fs_ocornut_imgui.bin.h",
                .includes = &.{shader_includes},
            },
        );

        const vs_imgui_image_bin_h = try zbgfx.build.compileBasicBinH(
            b,
            target,
            shaderc,
            combine_bin_h,
            .{
                .shaderType = .vertex,
                .input = b.path(bgfx_imgui_path ++ "vs_imgui_image.sc"),
            },
            .{
                .bin2c = "vs_imgui_image",
                .output = bgfx_imgui_path ++ "vs_imgui_image.bin.h",
                .includes = &.{shader_includes},
            },
        );

        const vs_ocornut_imgui_bin_h = try zbgfx.build.compileBasicBinH(
            b,
            target,
            shaderc,
            combine_bin_h,
            .{
                .shaderType = .vertex,
                .input = b.path(bgfx_imgui_path ++ "vs_ocornut_imgui.sc"),
            },
            .{
                .bin2c = "vs_ocornut_imgui",
                .output = bgfx_imgui_path ++ "vs_ocornut_imgui.bin.h",
                .includes = &.{shader_includes},
            },
        );
        compile_imgui_shaders.dependOn(fs_imgui_image_bin_h);
        compile_imgui_shaders.dependOn(fs_ocornut_imgui_bin_h);
        compile_imgui_shaders.dependOn(vs_imgui_image_bin_h);
        compile_imgui_shaders.dependOn(vs_ocornut_imgui_bin_h);

        //
        // fcpp
        //
        const fcpp_cxx_options = [_][]const u8{
            "-D__STDC_LIMIT_MACROS",
            "-D__STDC_FORMAT_MACROS",
            "-D__STDC_CONSTANT_MACROS",
            "-DNINCLUDE=64",
            "-DNWORK=65536",
            "-DNBUFF=65536",
            "-DOLD_PREPROCESSOR=0",
            "-fno-sanitize=undefined",
            "-Wno-error=date-time",
        };

        const fcpp_path = "libs/bgfx/3rdparty/fcpp/";
        const fcpp_lib = b.addLibrary(.{
            .linkage = .static,
            .name = "fcpp",
            .root_module = b.createModule(.{
                .target = target,
                .optimize = optimize,
            }),
        });

        fcpp_lib.addIncludePath(b.path(fcpp_path));
        fcpp_lib.addCSourceFiles(
            .{
                .files = &.{
                    fcpp_path ++ "cpp1.c",
                    fcpp_path ++ "cpp2.c",
                    fcpp_path ++ "cpp3.c",
                    fcpp_path ++ "cpp4.c",
                    fcpp_path ++ "cpp5.c",
                    fcpp_path ++ "cpp6.c",
                },
                .flags = &fcpp_cxx_options,
            },
        );
        fcpp_lib.linkLibCpp();

        //
        //spirv-opt
        //
        const spirv_opt_cxx_options = [_][]const u8{
            "-D__STDC_LIMIT_MACROS",
            "-D__STDC_FORMAT_MACROS",
            "-D__STDC_CONSTANT_MACROS",
            "-fno-sanitize=undefined",
        };

        const spirv_opt_lib = b.addLibrary(.{
            .name = "spirv-opt",
            .root_module = b.createModule(.{
                .target = target,
                .optimize = optimize,
            }),
        });
        spirv_opt_lib.addIncludePath(b.path(spirv_opt_path));
        spirv_opt_lib.addIncludePath(b.path(spirv_opt_path ++ "include"));
        spirv_opt_lib.addIncludePath(b.path(spirv_opt_path ++ "include/generated"));
        spirv_opt_lib.addIncludePath(b.path(spirv_opt_path ++ "source"));
        spirv_opt_lib.addIncludePath(b.path("libs/bgfx/3rdparty/spirv-headers/include"));

        spirv_opt_lib.addCSourceFiles(
            .{
                .files = &spirv_opt_files,
                .flags = &spirv_opt_cxx_options,
            },
        );

        spirv_opt_lib.linkLibCpp();

        //
        // spriv-cross
        //
        const spirv_cross_cxx_options = [_][]const u8{
            "-D__STDC_LIMIT_MACROS",
            "-D__STDC_FORMAT_MACROS",
            "-D__STDC_CONSTANT_MACROS",
            "-DSPIRV_CROSS_EXCEPTIONS_TO_ASSERTIONS",
            "-fno-sanitize=undefined",
        };

        const spirv_cross_path = "libs/bgfx/3rdparty/spirv-cross/";
        const spirv_cross_lib = b.addLibrary(.{
            .name = "spirv-cross",
            .root_module = b.createModule(.{
                .target = target,
                .optimize = optimize,
            }),
            .use_llvm = true,
        });
        spirv_cross_lib.addIncludePath(b.path(spirv_cross_path ++ "include"));
        spirv_cross_lib.addCSourceFiles(.{
            .files = &.{
                spirv_cross_path ++ "spirv_cfg.cpp",
                spirv_cross_path ++ "spirv_cpp.cpp",
                spirv_cross_path ++ "spirv_cross.cpp",
                spirv_cross_path ++ "spirv_cross_parsed_ir.cpp",
                spirv_cross_path ++ "spirv_cross_util.cpp",
                spirv_cross_path ++ "spirv_glsl.cpp",
                spirv_cross_path ++ "spirv_hlsl.cpp",
                spirv_cross_path ++ "spirv_msl.cpp",
                spirv_cross_path ++ "spirv_parser.cpp",
                spirv_cross_path ++ "spirv_reflect.cpp",
            },
            .flags = &spirv_cross_cxx_options,
        });

        spirv_cross_lib.linkLibCpp();

        //
        // glslang
        //
        const glslang_cxx_options = [_][]const u8{
            "-D__STDC_LIMIT_MACROS",
            "-D__STDC_FORMAT_MACROS",
            "-D__STDC_CONSTANT_MACROS",
            "-DENABLE_OPT=1",
            "-DENABLE_HLSL=1",
            "-fno-sanitize=undefined",
        };

        const glslang_lib = b.addLibrary(.{
            .name = "glslang",
            .root_module = b.createModule(.{
                .target = target,
                .optimize = optimize,
            }),
            .use_llvm = true,
        });
        glslang_lib.addIncludePath(b.path("libs/bgfx/3rdparty"));
        glslang_lib.addIncludePath(b.path(glslang_path));
        glslang_lib.addIncludePath(b.path(glslang_path ++ "include"));
        glslang_lib.addSystemIncludePath(b.path(spirv_opt_path ++ "include"));
        glslang_lib.addSystemIncludePath(b.path(spirv_opt_path ++ "source"));
        glslang_lib.addCSourceFiles(
            .{
                .files = &glsl_lang_files,
                .flags = &glslang_cxx_options,
            },
        );

        if (target.result.os.tag == .windows) {
            glslang_lib.addCSourceFile(.{
                .file = b.path(glslang_path ++ "glslang/OSDependent/Windows/ossource.cpp"),
                .flags = &glslang_cxx_options,
            });
        }
        if (target.result.os.tag == .linux or target.result.isDarwinLibC()) {
            glslang_lib.addCSourceFile(.{
                .file = b.path(glslang_path ++ "glslang/OSDependent/Unix/ossource.cpp"),
                .flags = &glslang_cxx_options,
            });
        }

        glslang_lib.linkLibCpp();

        // glslang
        const glsl_optimizer_cxx_options = [_][]const u8{
            "-MMD",
            "-MP",
            "-MP",
            "-Wall",
            "-Wextra",
            // https://github.com/bkaradzic/bgfx/commit/b4dbc129f3b69b0d6a9093f2d579b883396a839f
            // "-ffast-math",
            "-fomit-frame-pointer",
            "-g",
            "-m64",
            "-std=c++14",
            "-fno-rtti",
            "-fno-exceptions",
            "-D__STDC_LIMIT_MACROS",
            "-D__STDC_FORMAT_MACROS",
            "-D__STDC_CONSTANT_MACROS",
            "-fno-sanitize=undefined",
        };

        const glsl_optimizer_c_options = [_][]const u8{
            "-MMD",
            "-MP",
            "-MP",
            "-Wall",
            "-Wextra",
            // https://github.com/bkaradzic/bgfx/commit/b4dbc129f3b69b0d6a9093f2d579b883396a839f
            // "-ffast-math",
            "-fomit-frame-pointer",
            "-g",
            "-m64",
            "-D__STDC_LIMIT_MACROS",
            "-D__STDC_FORMAT_MACROS",
            "-D__STDC_CONSTANT_MACROS",
            "-fno-sanitize=undefined",
        };

        const glsl_optimizer_lib = b.addLibrary(.{
            .name = "glsl-optimizer",
            .root_module = b.createModule(.{
                .target = target,
                .optimize = optimize,
            }),
            .use_llvm = true,
        });
        glsl_optimizer_lib.addIncludePath(b.path(glsl_optimizer_path ++ "include"));
        glsl_optimizer_lib.addIncludePath(b.path(glsl_optimizer_path ++ "src"));
        glsl_optimizer_lib.addIncludePath(b.path(glsl_optimizer_path ++ "src/mesa"));
        glsl_optimizer_lib.addIncludePath(b.path(glsl_optimizer_path ++ "src/mapi"));
        glsl_optimizer_lib.addIncludePath(b.path(glsl_optimizer_path ++ "src/glsl"));

        // add C++ files
        glsl_optimizer_lib.addCSourceFiles(.{
            .files = &glsl_optimizer_files,
            .flags = &glsl_optimizer_cxx_options,
        });

        glsl_optimizer_lib.addCSourceFiles(
            .{
                .files = &.{
                    glsl_optimizer_path ++ "src/glsl/glcpp/glcpp-lex.c",
                    glsl_optimizer_path ++ "src/glsl/glcpp/glcpp-parse.c",
                    glsl_optimizer_path ++ "src/glsl/glcpp/pp.c",
                    glsl_optimizer_path ++ "src/glsl/strtod.c",
                    glsl_optimizer_path ++ "src/mesa/main/imports.c",
                    glsl_optimizer_path ++ "src/mesa/program/prog_hash_table.c",
                    glsl_optimizer_path ++ "src/mesa/program/symbol_table.c",
                    glsl_optimizer_path ++ "src/util/hash_table.c",
                    glsl_optimizer_path ++ "src/util/ralloc.c",
                },
                .flags = &glsl_optimizer_c_options,
            },
        );

        glsl_optimizer_lib.linkLibCpp();

        shaderc.linkLibrary(fcpp_lib);
        shaderc.linkLibrary(glslang_lib);
        shaderc.linkLibrary(glsl_optimizer_lib);
        shaderc.linkLibrary(spirv_opt_lib);
        shaderc.linkLibrary(spirv_cross_lib);
    }
}

fn bxInclude(b: *std.Build, step: *std.Build.Step.Compile, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) void {
    step.root_module.addCMacro("__STDC_LIMIT_MACROS", "1");
    step.root_module.addCMacro("__STDC_FORMAT_MACROS", "1");
    step.root_module.addCMacro("__STDC_CONSTANT_MACROS", "1");

    // FIXME: problem with compile with zig.
    if (target.result.os.tag == .windows) {
        step.root_module.addCMacro("BX_CONFIG_EXCEPTION_HANDLING_USE_WINDOWS_SEH", "0");
    } else if (target.result.os.tag == .linux) {
        step.root_module.addCMacro("BX_CONFIG_EXCEPTION_HANDLING_USE_POSIX_SIGNALS", "0");
    }

    step.root_module.addCMacro("BX_CONFIG_DEBUG", if (optimize == .Debug) "1" else "0");

    switch (target.result.os.tag) {
        .freebsd => step.addIncludePath(b.path("libs/bx/include/compat/freebsd")),
        .linux => step.addIncludePath(b.path("libs/bx/include/compat/linux")),
        .ios => step.addIncludePath(b.path("libs/bx/include/compat/ios")),
        .macos => step.addIncludePath(b.path("libs/bx/include/compat/osx")),
        .windows => switch (target.result.abi) {
            .gnu => step.addIncludePath(b.path("libs/bx/include/compat/mingw")),
            .msvc => step.addIncludePath(b.path("libs/bx/include/compat/msvc")),
            else => {},
        },
        else => {},
    }

    step.addIncludePath(b.path("libs/bx/include"));
    step.addIncludePath(b.path("libs/bx/3rdparty"));
}

fn bimgInclude(b: *std.Build, step: *std.Build.Step.Compile) void {
    step.addIncludePath(b.path("libs/bimg/include"));
    step.addIncludePath(b.path("libs/bimg/3rdparty"));
    step.addIncludePath(b.path("libs/bimg/3rdparty/astc-encoder/include"));
    step.addIncludePath(b.path("libs/bimg/3rdparty/tinyexr/deps/miniz"));
}

fn bgfxInclude(b: *std.Build, step: *std.Build.Step.Compile, target: std.Build.ResolvedTarget) void {
    step.addIncludePath(b.path("libs/bgfx/include"));
    step.addIncludePath(b.path("libs/bgfx/3rdparty"));
    step.addIncludePath(b.path("libs/bgfx/3rdparty/khronos/"));

    if (target.result.os.tag == .linux) {
        step.addIncludePath(b.path("libs/bgfx/3rdparty/directx-headers/include/directx"));
        step.addIncludePath(b.path("libs/bgfx/3rdparty/directx-headers/include"));
        step.addIncludePath(b.path("libs/bgfx/3rdparty/directx-headers/include/wsl/stubs"));
    }

    if (target.result.os.tag == .windows) {
        step.addIncludePath(b.path("libs/bgfx/3rdparty/directx-headers/include/directx"));
    }
}

//
// Path const
//
const glsl_optimizer_path = "libs/bgfx/3rdparty/glsl-optimizer/";
const glslang_path = "libs/bgfx/3rdparty/glslang/";
const spirv_opt_path = "libs/bgfx/3rdparty/spirv-tools/";

//
// Many files
//

const bimg_files = .{
    "libs/bimg/src/image.cpp",
    "libs/bimg/src/image_gnf.cpp",
    "libs/bimg/3rdparty/astc-encoder/source/astcenc_averages_and_directions.cpp",
    "libs/bimg/3rdparty/astc-encoder/source/astcenc_block_sizes.cpp",
    "libs/bimg/3rdparty/astc-encoder/source/astcenc_color_quantize.cpp",
    "libs/bimg/3rdparty/astc-encoder/source/astcenc_color_unquantize.cpp",
    "libs/bimg/3rdparty/astc-encoder/source/astcenc_compress_symbolic.cpp",
    "libs/bimg/3rdparty/astc-encoder/source/astcenc_compute_variance.cpp",
    "libs/bimg/3rdparty/astc-encoder/source/astcenc_decompress_symbolic.cpp",
    "libs/bimg/3rdparty/astc-encoder/source/astcenc_diagnostic_trace.cpp",
    "libs/bimg/3rdparty/astc-encoder/source/astcenc_entry.cpp",
    "libs/bimg/3rdparty/astc-encoder/source/astcenc_find_best_partitioning.cpp",
    "libs/bimg/3rdparty/astc-encoder/source/astcenc_ideal_endpoints_and_weights.cpp",
    "libs/bimg/3rdparty/astc-encoder/source/astcenc_image.cpp",
    "libs/bimg/3rdparty/astc-encoder/source/astcenc_integer_sequence.cpp",
    "libs/bimg/3rdparty/astc-encoder/source/astcenc_mathlib_softfloat.cpp",
    "libs/bimg/3rdparty/astc-encoder/source/astcenc_mathlib.cpp",
    "libs/bimg/3rdparty/astc-encoder/source/astcenc_partition_tables.cpp",
    "libs/bimg/3rdparty/astc-encoder/source/astcenc_percentile_tables.cpp",
    "libs/bimg/3rdparty/astc-encoder/source/astcenc_pick_best_endpoint_format.cpp",
    "libs/bimg/3rdparty/astc-encoder/source/astcenc_quantization.cpp",
    "libs/bimg/3rdparty/astc-encoder/source/astcenc_symbolic_physical.cpp",
    "libs/bimg/3rdparty/astc-encoder/source/astcenc_weight_align.cpp",
    "libs/bimg/3rdparty/astc-encoder/source/astcenc_weight_quant_xfer_tables.cpp",
};

const glsl_optimizer_files = .{
    glsl_optimizer_path ++ "src/glsl/ast_array_index.cpp",
    glsl_optimizer_path ++ "src/glsl/ast_expr.cpp",
    glsl_optimizer_path ++ "src/glsl/ast_function.cpp",
    glsl_optimizer_path ++ "src/glsl/ast_to_hir.cpp",
    glsl_optimizer_path ++ "src/glsl/ast_type.cpp",
    glsl_optimizer_path ++ "src/glsl/builtin_functions.cpp",
    glsl_optimizer_path ++ "src/glsl/builtin_types.cpp",
    glsl_optimizer_path ++ "src/glsl/builtin_variables.cpp",
    glsl_optimizer_path ++ "src/glsl/glsl_lexer.cpp",
    glsl_optimizer_path ++ "src/glsl/glsl_optimizer.cpp",
    glsl_optimizer_path ++ "src/glsl/glsl_parser.cpp",
    glsl_optimizer_path ++ "src/glsl/glsl_parser_extras.cpp",
    glsl_optimizer_path ++ "src/glsl/glsl_symbol_table.cpp",
    glsl_optimizer_path ++ "src/glsl/glsl_types.cpp",
    glsl_optimizer_path ++ "src/glsl/hir_field_selection.cpp",
    glsl_optimizer_path ++ "src/glsl/ir.cpp",
    glsl_optimizer_path ++ "src/glsl/ir_basic_block.cpp",
    glsl_optimizer_path ++ "src/glsl/ir_builder.cpp",
    glsl_optimizer_path ++ "src/glsl/ir_clone.cpp",
    glsl_optimizer_path ++ "src/glsl/ir_constant_expression.cpp",
    glsl_optimizer_path ++ "src/glsl/ir_equals.cpp",
    glsl_optimizer_path ++ "src/glsl/ir_expression_flattening.cpp",
    glsl_optimizer_path ++ "src/glsl/ir_function.cpp",
    glsl_optimizer_path ++ "src/glsl/ir_function_can_inline.cpp",
    glsl_optimizer_path ++ "src/glsl/ir_function_detect_recursion.cpp",
    glsl_optimizer_path ++ "src/glsl/ir_hierarchical_visitor.cpp",
    glsl_optimizer_path ++ "src/glsl/ir_hv_accept.cpp",
    glsl_optimizer_path ++ "src/glsl/ir_import_prototypes.cpp",
    glsl_optimizer_path ++ "src/glsl/ir_print_glsl_visitor.cpp",
    glsl_optimizer_path ++ "src/glsl/ir_print_metal_visitor.cpp",
    glsl_optimizer_path ++ "src/glsl/ir_print_visitor.cpp",
    glsl_optimizer_path ++ "src/glsl/ir_rvalue_visitor.cpp",
    glsl_optimizer_path ++ "src/glsl/ir_stats.cpp",
    glsl_optimizer_path ++ "src/glsl/ir_unused_structs.cpp",
    glsl_optimizer_path ++ "src/glsl/ir_validate.cpp",
    glsl_optimizer_path ++ "src/glsl/ir_variable_refcount.cpp",
    glsl_optimizer_path ++ "src/glsl/link_atomics.cpp",
    glsl_optimizer_path ++ "src/glsl/link_functions.cpp",
    glsl_optimizer_path ++ "src/glsl/link_interface_blocks.cpp",
    glsl_optimizer_path ++ "src/glsl/link_uniform_block_active_visitor.cpp",
    glsl_optimizer_path ++ "src/glsl/link_uniform_blocks.cpp",
    glsl_optimizer_path ++ "src/glsl/link_uniform_initializers.cpp",
    glsl_optimizer_path ++ "src/glsl/link_uniforms.cpp",
    glsl_optimizer_path ++ "src/glsl/link_varyings.cpp",
    glsl_optimizer_path ++ "src/glsl/linker.cpp",
    glsl_optimizer_path ++ "src/glsl/loop_analysis.cpp",
    glsl_optimizer_path ++ "src/glsl/loop_controls.cpp",
    glsl_optimizer_path ++ "src/glsl/loop_unroll.cpp",
    glsl_optimizer_path ++ "src/glsl/lower_clip_distance.cpp",
    glsl_optimizer_path ++ "src/glsl/lower_discard.cpp",
    glsl_optimizer_path ++ "src/glsl/lower_discard_flow.cpp",
    glsl_optimizer_path ++ "src/glsl/lower_if_to_cond_assign.cpp",
    glsl_optimizer_path ++ "src/glsl/lower_instructions.cpp",
    glsl_optimizer_path ++ "src/glsl/lower_jumps.cpp",
    glsl_optimizer_path ++ "src/glsl/lower_mat_op_to_vec.cpp",
    glsl_optimizer_path ++ "src/glsl/lower_named_interface_blocks.cpp",
    glsl_optimizer_path ++ "src/glsl/lower_noise.cpp",
    glsl_optimizer_path ++ "src/glsl/lower_offset_array.cpp",
    glsl_optimizer_path ++ "src/glsl/lower_output_reads.cpp",
    glsl_optimizer_path ++ "src/glsl/lower_packed_varyings.cpp",
    glsl_optimizer_path ++ "src/glsl/lower_packing_builtins.cpp",
    glsl_optimizer_path ++ "src/glsl/lower_ubo_reference.cpp",
    glsl_optimizer_path ++ "src/glsl/lower_variable_index_to_cond_assign.cpp",
    glsl_optimizer_path ++ "src/glsl/lower_vec_index_to_cond_assign.cpp",
    glsl_optimizer_path ++ "src/glsl/lower_vec_index_to_swizzle.cpp",
    glsl_optimizer_path ++ "src/glsl/lower_vector.cpp",
    glsl_optimizer_path ++ "src/glsl/lower_vector_insert.cpp",
    glsl_optimizer_path ++ "src/glsl/lower_vertex_id.cpp",
    glsl_optimizer_path ++ "src/glsl/opt_algebraic.cpp",
    glsl_optimizer_path ++ "src/glsl/opt_array_splitting.cpp",
    glsl_optimizer_path ++ "src/glsl/opt_constant_folding.cpp",
    glsl_optimizer_path ++ "src/glsl/opt_constant_propagation.cpp",
    glsl_optimizer_path ++ "src/glsl/opt_constant_variable.cpp",
    glsl_optimizer_path ++ "src/glsl/opt_copy_propagation.cpp",
    glsl_optimizer_path ++ "src/glsl/opt_copy_propagation_elements.cpp",
    glsl_optimizer_path ++ "src/glsl/opt_cse.cpp",
    glsl_optimizer_path ++ "src/glsl/opt_dead_builtin_variables.cpp",
    glsl_optimizer_path ++ "src/glsl/opt_dead_builtin_varyings.cpp",
    glsl_optimizer_path ++ "src/glsl/opt_dead_code.cpp",
    glsl_optimizer_path ++ "src/glsl/opt_dead_code_local.cpp",
    glsl_optimizer_path ++ "src/glsl/opt_dead_functions.cpp",
    glsl_optimizer_path ++ "src/glsl/opt_flatten_nested_if_blocks.cpp",
    glsl_optimizer_path ++ "src/glsl/opt_flip_matrices.cpp",
    glsl_optimizer_path ++ "src/glsl/opt_function_inlining.cpp",
    glsl_optimizer_path ++ "src/glsl/opt_if_simplification.cpp",
    glsl_optimizer_path ++ "src/glsl/opt_minmax.cpp",
    glsl_optimizer_path ++ "src/glsl/opt_noop_swizzle.cpp",
    glsl_optimizer_path ++ "src/glsl/opt_rebalance_tree.cpp",
    glsl_optimizer_path ++ "src/glsl/opt_redundant_jumps.cpp",
    glsl_optimizer_path ++ "src/glsl/opt_structure_splitting.cpp",
    glsl_optimizer_path ++ "src/glsl/opt_swizzle_swizzle.cpp",
    glsl_optimizer_path ++ "src/glsl/opt_tree_grafting.cpp",
    glsl_optimizer_path ++ "src/glsl/opt_vectorize.cpp",
    glsl_optimizer_path ++ "src/glsl/s_expression.cpp",
    glsl_optimizer_path ++ "src/glsl/standalone_scaffolding.cpp",
};

const glsl_lang_files = .{
    glslang_path ++ "SPIRV/GlslangToSpv.cpp",
    glslang_path ++ "SPIRV/InReadableOrder.cpp",
    glslang_path ++ "SPIRV/Logger.cpp",
    glslang_path ++ "SPIRV/SPVRemapper.cpp",
    glslang_path ++ "SPIRV/SpvBuilder.cpp",
    glslang_path ++ "SPIRV/SpvPostProcess.cpp",
    glslang_path ++ "SPIRV/SpvTools.cpp",
    glslang_path ++ "SPIRV/disassemble.cpp",
    glslang_path ++ "SPIRV/doc.cpp",
    glslang_path ++ "glslang/stub.cpp",
    glslang_path ++ "glslang/GenericCodeGen/CodeGen.cpp",
    glslang_path ++ "glslang/GenericCodeGen/Link.cpp",
    glslang_path ++ "glslang/HLSL/hlslAttributes.cpp",
    glslang_path ++ "glslang/HLSL/hlslGrammar.cpp",
    glslang_path ++ "glslang/HLSL/hlslOpMap.cpp",
    glslang_path ++ "glslang/HLSL/hlslParseHelper.cpp",
    glslang_path ++ "glslang/HLSL/hlslParseables.cpp",
    glslang_path ++ "glslang/HLSL/hlslScanContext.cpp",
    glslang_path ++ "glslang/HLSL/hlslTokenStream.cpp",
    glslang_path ++ "glslang/MachineIndependent/Constant.cpp",
    glslang_path ++ "glslang/MachineIndependent/InfoSink.cpp",
    glslang_path ++ "glslang/MachineIndependent/Initialize.cpp",
    glslang_path ++ "glslang/MachineIndependent/IntermTraverse.cpp",
    glslang_path ++ "glslang/MachineIndependent/Intermediate.cpp",
    glslang_path ++ "glslang/MachineIndependent/ParseContextBase.cpp",
    glslang_path ++ "glslang/MachineIndependent/ParseHelper.cpp",
    glslang_path ++ "glslang/MachineIndependent/PoolAlloc.cpp",
    glslang_path ++ "glslang/MachineIndependent/RemoveTree.cpp",
    glslang_path ++ "glslang/MachineIndependent/Scan.cpp",
    glslang_path ++ "glslang/MachineIndependent/ShaderLang.cpp",
    glslang_path ++ "glslang/MachineIndependent/SymbolTable.cpp",
    glslang_path ++ "glslang/MachineIndependent/SpirvIntrinsics.cpp",
    glslang_path ++ "glslang/MachineIndependent/Versions.cpp",
    glslang_path ++ "glslang/MachineIndependent/attribute.cpp",
    glslang_path ++ "glslang/MachineIndependent/glslang_tab.cpp",
    glslang_path ++ "glslang/MachineIndependent/intermOut.cpp",
    glslang_path ++ "glslang/MachineIndependent/iomapper.cpp",
    glslang_path ++ "glslang/MachineIndependent/limits.cpp",
    glslang_path ++ "glslang/MachineIndependent/linkValidate.cpp",
    glslang_path ++ "glslang/MachineIndependent/parseConst.cpp",
    glslang_path ++ "glslang/MachineIndependent/preprocessor/Pp.cpp",
    glslang_path ++ "glslang/MachineIndependent/preprocessor/PpAtom.cpp",
    glslang_path ++ "glslang/MachineIndependent/preprocessor/PpContext.cpp",
    glslang_path ++ "glslang/MachineIndependent/preprocessor/PpScanner.cpp",
    glslang_path ++ "glslang/MachineIndependent/preprocessor/PpTokens.cpp",
    glslang_path ++ "glslang/MachineIndependent/propagateNoContraction.cpp",
    glslang_path ++ "glslang/MachineIndependent/reflection.cpp",
};

const spirv_opt_files = .{
    spirv_opt_path ++ "source/assembly_grammar.cpp",
    spirv_opt_path ++ "source/binary.cpp",
    spirv_opt_path ++ "source/diagnostic.cpp",
    spirv_opt_path ++ "source/disassemble.cpp",
    spirv_opt_path ++ "source/ext_inst.cpp",
    spirv_opt_path ++ "source/extensions.cpp",
    spirv_opt_path ++ "source/libspirv.cpp",
    spirv_opt_path ++ "source/name_mapper.cpp",
    spirv_opt_path ++ "source/opcode.cpp",
    spirv_opt_path ++ "source/operand.cpp",
    spirv_opt_path ++ "source/to_string.cpp",
    spirv_opt_path ++ "source/opt/graph.cpp",
    spirv_opt_path ++ "source/opt/aggressive_dead_code_elim_pass.cpp",
    spirv_opt_path ++ "source/opt/amd_ext_to_khr.cpp",
    spirv_opt_path ++ "source/opt/analyze_live_input_pass.cpp",
    spirv_opt_path ++ "source/opt/basic_block.cpp",
    spirv_opt_path ++ "source/opt/block_merge_pass.cpp",
    spirv_opt_path ++ "source/opt/block_merge_util.cpp",
    spirv_opt_path ++ "source/opt/build_module.cpp",
    spirv_opt_path ++ "source/opt/ccp_pass.cpp",
    spirv_opt_path ++ "source/opt/cfg.cpp",
    spirv_opt_path ++ "source/opt/cfg_cleanup_pass.cpp",
    spirv_opt_path ++ "source/opt/code_sink.cpp",
    spirv_opt_path ++ "source/opt/combine_access_chains.cpp",
    spirv_opt_path ++ "source/opt/compact_ids_pass.cpp",
    spirv_opt_path ++ "source/opt/composite.cpp",
    spirv_opt_path ++ "source/opt/const_folding_rules.cpp",
    spirv_opt_path ++ "source/opt/constants.cpp",
    spirv_opt_path ++ "source/opt/control_dependence.cpp",
    spirv_opt_path ++ "source/opt/convert_to_half_pass.cpp",
    spirv_opt_path ++ "source/opt/convert_to_sampled_image_pass.cpp",
    spirv_opt_path ++ "source/opt/copy_prop_arrays.cpp",
    spirv_opt_path ++ "source/opt/dataflow.cpp",
    spirv_opt_path ++ "source/opt/dead_branch_elim_pass.cpp",
    spirv_opt_path ++ "source/opt/dead_insert_elim_pass.cpp",
    spirv_opt_path ++ "source/opt/dead_variable_elimination.cpp",
    spirv_opt_path ++ "source/opt/debug_info_manager.cpp",
    spirv_opt_path ++ "source/opt/decoration_manager.cpp",
    spirv_opt_path ++ "source/opt/def_use_manager.cpp",
    spirv_opt_path ++ "source/opt/desc_sroa.cpp",
    spirv_opt_path ++ "source/opt/desc_sroa_util.cpp",
    spirv_opt_path ++ "source/opt/dominator_analysis.cpp",
    spirv_opt_path ++ "source/opt/dominator_tree.cpp",
    spirv_opt_path ++ "source/opt/eliminate_dead_constant_pass.cpp",
    spirv_opt_path ++ "source/opt/eliminate_dead_functions_pass.cpp",
    spirv_opt_path ++ "source/opt/eliminate_dead_functions_util.cpp",
    spirv_opt_path ++ "source/opt/eliminate_dead_io_components_pass.cpp",
    spirv_opt_path ++ "source/opt/eliminate_dead_members_pass.cpp",
    spirv_opt_path ++ "source/opt/eliminate_dead_output_stores_pass.cpp",
    spirv_opt_path ++ "source/opt/feature_manager.cpp",
    spirv_opt_path ++ "source/opt/fix_func_call_arguments.cpp",
    spirv_opt_path ++ "source/opt/fix_storage_class.cpp",
    spirv_opt_path ++ "source/opt/flatten_decoration_pass.cpp",
    spirv_opt_path ++ "source/opt/fold.cpp",
    spirv_opt_path ++ "source/opt/fold_spec_constant_op_and_composite_pass.cpp",
    spirv_opt_path ++ "source/opt/folding_rules.cpp",
    spirv_opt_path ++ "source/opt/freeze_spec_constant_value_pass.cpp",
    spirv_opt_path ++ "source/opt/function.cpp",
    spirv_opt_path ++ "source/opt/graphics_robust_access_pass.cpp",
    spirv_opt_path ++ "source/opt/if_conversion.cpp",
    spirv_opt_path ++ "source/opt/inline_exhaustive_pass.cpp",
    spirv_opt_path ++ "source/opt/inline_opaque_pass.cpp",
    spirv_opt_path ++ "source/opt/inline_pass.cpp",
    spirv_opt_path ++ "source/opt/inst_bindless_check_pass.cpp",
    spirv_opt_path ++ "source/opt/inst_buff_addr_check_pass.cpp",
    spirv_opt_path ++ "source/opt/inst_debug_printf_pass.cpp",
    spirv_opt_path ++ "source/opt/instruction.cpp",
    spirv_opt_path ++ "source/opt/instruction_list.cpp",
    spirv_opt_path ++ "source/opt/instrument_pass.cpp",
    spirv_opt_path ++ "source/opt/interface_var_sroa.cpp",
    spirv_opt_path ++ "source/opt/interp_fixup_pass.cpp",
    spirv_opt_path ++ "source/opt/invocation_interlock_placement_pass.cpp",
    spirv_opt_path ++ "source/opt/ir_context.cpp",
    spirv_opt_path ++ "source/opt/ir_loader.cpp",
    spirv_opt_path ++ "source/opt/licm_pass.cpp",
    spirv_opt_path ++ "source/opt/liveness.cpp",
    spirv_opt_path ++ "source/opt/local_access_chain_convert_pass.cpp",
    spirv_opt_path ++ "source/opt/local_redundancy_elimination.cpp",
    spirv_opt_path ++ "source/opt/local_single_block_elim_pass.cpp",
    spirv_opt_path ++ "source/opt/local_single_store_elim_pass.cpp",
    spirv_opt_path ++ "source/opt/loop_dependence.cpp",
    spirv_opt_path ++ "source/opt/loop_dependence_helpers.cpp",
    spirv_opt_path ++ "source/opt/loop_descriptor.cpp",
    spirv_opt_path ++ "source/opt/loop_fission.cpp",
    spirv_opt_path ++ "source/opt/loop_fusion.cpp",
    spirv_opt_path ++ "source/opt/loop_fusion_pass.cpp",
    spirv_opt_path ++ "source/opt/loop_peeling.cpp",
    spirv_opt_path ++ "source/opt/loop_unroller.cpp",
    spirv_opt_path ++ "source/opt/loop_unswitch_pass.cpp",
    spirv_opt_path ++ "source/opt/loop_utils.cpp",
    spirv_opt_path ++ "source/opt/mem_pass.cpp",
    spirv_opt_path ++ "source/opt/merge_return_pass.cpp",
    spirv_opt_path ++ "source/opt/modify_maximal_reconvergence.cpp",
    spirv_opt_path ++ "source/opt/module.cpp",
    spirv_opt_path ++ "source/opt/optimizer.cpp",
    spirv_opt_path ++ "source/opt/pass.cpp",
    spirv_opt_path ++ "source/opt/pass_manager.cpp",
    spirv_opt_path ++ "source/opt/pch_source_opt.cpp",
    spirv_opt_path ++ "source/opt/private_to_local_pass.cpp",
    spirv_opt_path ++ "source/opt/propagator.cpp",
    spirv_opt_path ++ "source/opt/reduce_load_size.cpp",
    spirv_opt_path ++ "source/opt/redundancy_elimination.cpp",
    spirv_opt_path ++ "source/opt/register_pressure.cpp",
    spirv_opt_path ++ "source/opt/relax_float_ops_pass.cpp",
    spirv_opt_path ++ "source/opt/remove_dontinline_pass.cpp",
    spirv_opt_path ++ "source/opt/remove_duplicates_pass.cpp",
    spirv_opt_path ++ "source/opt/remove_unused_interface_variables_pass.cpp",
    spirv_opt_path ++ "source/opt/replace_desc_array_access_using_var_index.cpp",
    spirv_opt_path ++ "source/opt/replace_invalid_opc.cpp",
    spirv_opt_path ++ "source/opt/scalar_analysis.cpp",
    spirv_opt_path ++ "source/opt/scalar_analysis_simplification.cpp",
    spirv_opt_path ++ "source/opt/scalar_replacement_pass.cpp",
    spirv_opt_path ++ "source/opt/set_spec_constant_default_value_pass.cpp",
    spirv_opt_path ++ "source/opt/simplification_pass.cpp",
    spirv_opt_path ++ "source/opt/spread_volatile_semantics.cpp",
    spirv_opt_path ++ "source/opt/ssa_rewrite_pass.cpp",
    spirv_opt_path ++ "source/opt/strength_reduction_pass.cpp",
    spirv_opt_path ++ "source/opt/strip_debug_info_pass.cpp",
    spirv_opt_path ++ "source/opt/strip_nonsemantic_info_pass.cpp",
    spirv_opt_path ++ "source/opt/struct_cfg_analysis.cpp",
    spirv_opt_path ++ "source/opt/switch_descriptorset_pass.cpp",
    spirv_opt_path ++ "source/opt/trim_capabilities_pass.cpp",
    spirv_opt_path ++ "source/opt/type_manager.cpp",
    spirv_opt_path ++ "source/opt/types.cpp",
    spirv_opt_path ++ "source/opt/unify_const_pass.cpp",
    spirv_opt_path ++ "source/opt/upgrade_memory_model.cpp",
    spirv_opt_path ++ "source/opt/value_number_table.cpp",
    spirv_opt_path ++ "source/opt/vector_dce.cpp",
    spirv_opt_path ++ "source/opt/workaround1209.cpp",
    spirv_opt_path ++ "source/opt/wrap_opkill.cpp",
    spirv_opt_path ++ "source/opt/opextinst_forward_ref_fixup_pass.cpp",
    spirv_opt_path ++ "source/opt/struct_packing_pass.cpp",
    spirv_opt_path ++ "source/opt/split_combined_image_sampler_pass.cpp",
    spirv_opt_path ++ "source/opt/resolve_binding_conflicts_pass.cpp",
    spirv_opt_path ++ "source/opt/canonicalize_ids_pass.cpp",
    spirv_opt_path ++ "source/parsed_operand.cpp",
    spirv_opt_path ++ "source/print.cpp",
    spirv_opt_path ++ "source/reduce/change_operand_reduction_opportunity.cpp",
    spirv_opt_path ++ "source/reduce/change_operand_to_undef_reduction_opportunity.cpp",
    spirv_opt_path ++ "source/reduce/conditional_branch_to_simple_conditional_branch_opportunity_finder.cpp",
    spirv_opt_path ++ "source/reduce/conditional_branch_to_simple_conditional_branch_reduction_opportunity.cpp",
    spirv_opt_path ++ "source/reduce/merge_blocks_reduction_opportunity.cpp",
    spirv_opt_path ++ "source/reduce/merge_blocks_reduction_opportunity_finder.cpp",
    spirv_opt_path ++ "source/reduce/operand_to_const_reduction_opportunity_finder.cpp",
    spirv_opt_path ++ "source/reduce/operand_to_dominating_id_reduction_opportunity_finder.cpp",
    spirv_opt_path ++ "source/reduce/operand_to_undef_reduction_opportunity_finder.cpp",
    spirv_opt_path ++ "source/reduce/pch_source_reduce.cpp",
    spirv_opt_path ++ "source/reduce/reducer.cpp",
    spirv_opt_path ++ "source/reduce/reduction_opportunity.cpp",
    spirv_opt_path ++ "source/reduce/reduction_opportunity_finder.cpp",
    spirv_opt_path ++ "source/reduce/reduction_pass.cpp",
    spirv_opt_path ++ "source/reduce/reduction_util.cpp",
    spirv_opt_path ++ "source/reduce/remove_block_reduction_opportunity.cpp",
    spirv_opt_path ++ "source/reduce/remove_block_reduction_opportunity_finder.cpp",
    spirv_opt_path ++ "source/reduce/remove_function_reduction_opportunity.cpp",
    spirv_opt_path ++ "source/reduce/remove_function_reduction_opportunity_finder.cpp",
    spirv_opt_path ++ "source/reduce/remove_instruction_reduction_opportunity.cpp",
    spirv_opt_path ++ "source/reduce/remove_selection_reduction_opportunity.cpp",
    spirv_opt_path ++ "source/reduce/remove_selection_reduction_opportunity_finder.cpp",
    spirv_opt_path ++ "source/reduce/remove_struct_member_reduction_opportunity.cpp",
    spirv_opt_path ++ "source/reduce/remove_unused_instruction_reduction_opportunity_finder.cpp",
    spirv_opt_path ++ "source/reduce/remove_unused_struct_member_reduction_opportunity_finder.cpp",
    spirv_opt_path ++ "source/reduce/simple_conditional_branch_to_branch_opportunity_finder.cpp",
    spirv_opt_path ++ "source/reduce/simple_conditional_branch_to_branch_reduction_opportunity.cpp",
    spirv_opt_path ++ "source/reduce/structured_construct_to_block_reduction_opportunity.cpp",
    spirv_opt_path ++ "source/reduce/structured_construct_to_block_reduction_opportunity_finder.cpp",
    spirv_opt_path ++ "source/reduce/structured_loop_to_selection_reduction_opportunity.cpp",
    spirv_opt_path ++ "source/reduce/structured_loop_to_selection_reduction_opportunity_finder.cpp",
    spirv_opt_path ++ "source/software_version.cpp",
    spirv_opt_path ++ "source/spirv_endian.cpp",
    spirv_opt_path ++ "source/spirv_optimizer_options.cpp",
    spirv_opt_path ++ "source/spirv_reducer_options.cpp",
    spirv_opt_path ++ "source/spirv_target_env.cpp",
    spirv_opt_path ++ "source/spirv_validator_options.cpp",
    spirv_opt_path ++ "source/table.cpp",
    spirv_opt_path ++ "source/table2.cpp",
    spirv_opt_path ++ "source/text.cpp",
    spirv_opt_path ++ "source/text_handler.cpp",
    spirv_opt_path ++ "source/util/bit_vector.cpp",
    spirv_opt_path ++ "source/util/parse_number.cpp",
    spirv_opt_path ++ "source/util/string_utils.cpp",
    spirv_opt_path ++ "source/val/basic_block.cpp",
    spirv_opt_path ++ "source/val/construct.cpp",
    spirv_opt_path ++ "source/val/function.cpp",
    spirv_opt_path ++ "source/val/instruction.cpp",
    spirv_opt_path ++ "source/val/validate.cpp",
    spirv_opt_path ++ "source/val/validate_adjacency.cpp",
    spirv_opt_path ++ "source/val/validate_annotation.cpp",
    spirv_opt_path ++ "source/val/validate_arithmetics.cpp",
    spirv_opt_path ++ "source/val/validate_atomics.cpp",
    spirv_opt_path ++ "source/val/validate_barriers.cpp",
    spirv_opt_path ++ "source/val/validate_bitwise.cpp",
    spirv_opt_path ++ "source/val/validate_builtins.cpp",
    spirv_opt_path ++ "source/val/validate_capability.cpp",
    spirv_opt_path ++ "source/val/validate_cfg.cpp",
    spirv_opt_path ++ "source/val/validate_composites.cpp",
    spirv_opt_path ++ "source/val/validate_constants.cpp",
    spirv_opt_path ++ "source/val/validate_conversion.cpp",
    spirv_opt_path ++ "source/val/validate_debug.cpp",
    spirv_opt_path ++ "source/val/validate_decorations.cpp",
    spirv_opt_path ++ "source/val/validate_derivatives.cpp",
    spirv_opt_path ++ "source/val/validate_execution_limitations.cpp",
    spirv_opt_path ++ "source/val/validate_extensions.cpp",
    spirv_opt_path ++ "source/val/validate_function.cpp",
    spirv_opt_path ++ "source/val/validate_id.cpp",
    spirv_opt_path ++ "source/val/validate_image.cpp",
    spirv_opt_path ++ "source/val/validate_instruction.cpp",
    spirv_opt_path ++ "source/val/validate_interfaces.cpp",
    spirv_opt_path ++ "source/val/validate_layout.cpp",
    spirv_opt_path ++ "source/val/validate_literals.cpp",
    spirv_opt_path ++ "source/val/validate_logicals.cpp",
    spirv_opt_path ++ "source/val/validate_memory.cpp",
    spirv_opt_path ++ "source/val/validate_memory_semantics.cpp",
    spirv_opt_path ++ "source/val/validate_mesh_shading.cpp",
    spirv_opt_path ++ "source/val/validate_misc.cpp",
    spirv_opt_path ++ "source/val/validate_mode_setting.cpp",
    spirv_opt_path ++ "source/val/validate_non_uniform.cpp",
    spirv_opt_path ++ "source/val/validate_primitives.cpp",
    spirv_opt_path ++ "source/val/validate_ray_query.cpp",
    spirv_opt_path ++ "source/val/validate_ray_tracing.cpp",
    spirv_opt_path ++ "source/val/validate_ray_tracing_reorder.cpp",
    spirv_opt_path ++ "source/val/validate_scopes.cpp",
    spirv_opt_path ++ "source/val/validate_small_type_uses.cpp",
    spirv_opt_path ++ "source/val/validate_type.cpp",
    spirv_opt_path ++ "source/val/validation_state.cpp",
    spirv_opt_path ++ "source/val/validate_tensor_layout.cpp",
    spirv_opt_path ++ "source/val/validate_tensor.cpp",
    spirv_opt_path ++ "source/val/validate_invalid_type.cpp",
    spirv_opt_path ++ "source/val/validate_graph.cpp",
};
