const std = @import("std");
const builtin = @import("builtin");

const math = std.math;
const zglfw = @import("zglfw");
const zm = @import("zmath");

const zbgfx = @import("zbgfx");
const bgfx = zbgfx.bgfx;
const shaderc = zbgfx.shaderc;

const WIDTH = 1280;
const HEIGHT = 720;

var bgfx_clbs = zbgfx.callbacks.CCallbackInterfaceT{
    .vtable = &zbgfx.callbacks.DefaultZigCallbackVTable.toVtbl(),
};
var bgfx_alloc: zbgfx.callbacks.ZigAllocator = undefined;

//
// Vertex layout definiton
//
const PosColorVertex = struct {
    x: f32,
    y: f32,
    z: f32,
    abgr: u32,

    fn init(x: f32, y: f32, z: f32, abgr: u32) PosColorVertex {
        return .{
            .x = x,
            .y = y,
            .z = z,
            .abgr = abgr,
        };
    }

    fn layoutInit() bgfx.VertexLayout {
        // static local
        const L = struct {
            var posColorLayout = std.mem.zeroes(bgfx.VertexLayout);
        };

        L.posColorLayout.begin(bgfx.RendererType.Noop)
            .add(bgfx.Attrib.Position, 3, bgfx.AttribType.Float, false, false)
            .add(bgfx.Attrib.Color0, 4, bgfx.AttribType.Uint8, true, false)
            .end();

        return L.posColorLayout;
    }
};

const cube_vertices = [_]PosColorVertex{
    PosColorVertex.init(-1.0, 1.0, 1.0, 0xff000000),
    PosColorVertex.init(1.0, 1.0, 1.0, 0xff0000ff),
    PosColorVertex.init(-1.0, -1.0, 1.0, 0xff00ff00),
    PosColorVertex.init(1.0, -1.0, 1.0, 0xff00ffff),
    PosColorVertex.init(-1.0, 1.0, -1.0, 0xffff0000),
    PosColorVertex.init(1.0, 1.0, -1.0, 0xffff00ff),
    PosColorVertex.init(-1.0, -1.0, -1.0, 0xffffff00),
    PosColorVertex.init(1.0, -1.0, -1.0, 0xffffffff),
};

const cube_tri_list = [_]u16{
    0, 1, 2, // 0
    1, 3, 2,
    4, 6, 5, // 2
    5, 6, 7,
    0, 2, 4, // 4
    4, 2, 6,
    1, 5, 3, // 6
    5, 7, 3,
    0, 4, 1, // 8
    4, 5, 1,
    2, 3, 6, // 10
    6, 3, 7,
};

var debug = true;
var vsync = true;

var last_v = zglfw.Action.release;
var last_d = zglfw.Action.release;
var last_r = zglfw.Action.release;
var old_flags = bgfx.ResetFlags_None;
var old_size = [2]i32{ WIDTH, HEIGHT };

pub fn buildProgram(io: std.Io, env_map: *const std.process.Environ.Map, allocator: std.mem.Allocator, shaderc_path: []const u8) !bgfx.ProgramHandle {
    // Load varying from file
    const varying_data = try readFileFromShaderDirs(io, allocator, "varying.def.sc");
    defer allocator.free(varying_data);

    // Load fs_cube shader
    const fs_cube_data = try readFileFromShaderDirs(io, allocator, "fs_cubes.sc");
    defer allocator.free(fs_cube_data);

    // Load vs_cube shader
    const vs_cube_data = try readFileFromShaderDirs(io, allocator, "vs_cubes.sc");
    defer allocator.free(vs_cube_data);

    const exe_dir = try std.process.executableDirPathAlloc(io, allocator);
    defer allocator.free(exe_dir);

    const path = try std.fs.path.join(allocator, &.{ exe_dir, "..", "include", "shaders" });
    defer allocator.free(path);

    const system_tmp_dir_path = try getSysTmpDir(allocator, env_map);
    defer allocator.free(system_tmp_dir_path);
    const tmp_dir_path = try std.fs.path.join(allocator, &.{ system_tmp_dir_path, "shaderc" });
    defer allocator.free(tmp_dir_path);

    // Compile fs shader
    var fs_shader_options = shaderc.createDefaultOptionsForRenderer(bgfx.getRendererType());
    fs_shader_options.shaderType = .fragment;
    fs_shader_options.includeDirs = &.{path};

    const fs_shader = try shaderc.compileShader(io, allocator, shaderc_path, varying_data, fs_cube_data, tmp_dir_path, fs_shader_options);
    defer allocator.free(fs_shader);

    // Compile vs shader
    var vs_shader_options = shaderc.createDefaultOptionsForRenderer(bgfx.getRendererType());
    vs_shader_options.shaderType = .vertex;
    vs_shader_options.includeDirs = &.{path};

    const vs_shader = try shaderc.compileShader(io, allocator, shaderc_path, varying_data, vs_cube_data, tmp_dir_path, vs_shader_options);
    defer allocator.free(vs_shader);

    //
    // Create bgfx shader and program
    //
    const fs_cubes = bgfx.createShader(bgfx.copy(fs_shader.ptr, @intCast(fs_shader.len)));
    const vs_cubes = bgfx.createShader(bgfx.copy(vs_shader.ptr, @intCast(vs_shader.len)));
    const programHandle = bgfx.createProgram(vs_cubes, fs_cubes, true);

    return programHandle;
}

pub fn main(init: std.process.Init) anyerror!u8 {
    //
    // Init zglfw
    //
    try zglfw.init();
    defer zglfw.terminate();

    //
    // Create window
    //
    zglfw.windowHint(.client_api, .no_api);
    const window = try zglfw.Window.create(WIDTH, HEIGHT, "ZBgfx - runtime shaderc", null, null);
    defer window.destroy();
    window.setSizeLimits(400, 400, -1, -1);

    //
    // Init bgfx init params
    //
    var bgfx_init: bgfx.Init = undefined;
    bgfx.initCtor(&bgfx_init);

    // This force renderer type.
    // bgfx_init.type = .Vulkan;

    const framebufferSize = window.getFramebufferSize();
    bgfx_init.resolution.width = @intCast(framebufferSize[0]);
    bgfx_init.resolution.height = @intCast(framebufferSize[1]);
    bgfx_init.platformData.ndt = null;
    bgfx_init.debug = true;

    // TODO: read note in zbgfx.callbacks.ZigAllocator
    //bgfx_alloc = zbgfx.callbacks.ZigAllocator.init(&_allocator);
    //bgfx_init.allocator = &bgfx_alloc;

    bgfx_init.callback = &bgfx_clbs;

    //
    // Set native handles
    //
    switch (builtin.target.os.tag) {
        .linux => {
            if (zglfw.getPlatform() == .wayland) {
                bgfx_init.platformData.type = bgfx.NativeWindowHandleType.Wayland;
                bgfx_init.platformData.nwh = zglfw.getWaylandWindow(window);
                bgfx_init.platformData.ndt = zglfw.getWaylandDisplay();
            } else {
                bgfx_init.platformData.type = .Default;
                bgfx_init.platformData.nwh = @ptrFromInt(zglfw.getX11Window(window));
                bgfx_init.platformData.ndt = zglfw.getX11Display();
            }
        },
        .windows => {
            bgfx_init.platformData.nwh = zglfw.getWin32Window(window);
        },
        else => |v| if (v.isDarwin()) {
            bgfx_init.platformData.nwh = zglfw.getCocoaWindow(window);
        } else undefined,
    }

    //
    // Init bgfx
    //

    // Do not create render thread
    _ = bgfx.renderFrame(-1);

    if (!bgfx.init(&bgfx_init)) std.process.exit(1);
    defer bgfx.shutdown();

    //
    // Create vertex buffer
    //
    const vertex_layout = PosColorVertex.layoutInit();
    const vbh = bgfx.createVertexBuffer(
        bgfx.makeRef(&cube_vertices, cube_vertices.len * @sizeOf(PosColorVertex)),
        &vertex_layout,
        bgfx.BufferFlags_None,
    );
    defer bgfx.destroyVertexBuffer(vbh);

    //
    // Create index buffer
    //
    const ibh = bgfx.createIndexBuffer(
        bgfx.makeRef(&cube_tri_list, cube_tri_list.len * @sizeOf(u16)),
        bgfx.BufferFlags_None,
    );
    defer bgfx.destroyIndexBuffer(ibh);

    //

    const gpa_allocator = init.gpa;

    const shaderc_path = try shaderc.shadercFromExePath(init.io, gpa_allocator);
    defer gpa_allocator.free(shaderc_path);

    var programHandle = buildProgram(init.io, init.environ_map, gpa_allocator, shaderc_path) catch |err| {
        std.log.err("Build program failed => {}", .{err});
        return 1;
    };
    defer bgfx.destroyProgram(programHandle);

    //
    // Shader and program
    //

    var reset_flags = bgfx.ResetFlags_None;
    if (vsync) {
        reset_flags |= bgfx.ResetFlags_Vsync;
    }

    //
    // Reset and clear
    //
    bgfx.reset(@intCast(framebufferSize[0]), @intCast(framebufferSize[1]), reset_flags, bgfx_init.resolution.formatColor);

    // Set view 0 clear state.
    bgfx.setViewClear(0, bgfx.ClearFlags_Color | bgfx.ClearFlags_Depth, 0x303030ff, 1.0, 0);

    //
    // Create view and proj matrices
    //
    const viewMtx = zm.lookAtRh(zm.f32x4(0.0, 0.0, -50.0, 1.0), zm.f32x4(0.0, 0.0, 0.0, 1.0), zm.f32x4(0.0, 1.0, 0.0, 0.0));
    var projMtx: zm.Mat = undefined;

    //
    // Default state
    //
    const state = 0 | bgfx.StateFlags_WriteRgb | bgfx.StateFlags_WriteA | bgfx.StateFlags_WriteZ | bgfx.StateFlags_DepthTestLess | bgfx.StateFlags_CullCcw | bgfx.StateFlags_Msaa;

    //
    // Main loop
    //

    const start = std.Io.Clock.awake.now(init.io);
    while (!window.shouldClose() and window.getKey(.escape) != .press) {
        //
        // Poll events
        //
        zglfw.pollEvents();

        //
        // Check keyboard
        //
        if (last_d != .press and window.getKey(.d) == .press) {
            debug = !debug;
        }
        if (last_v != .press and window.getKey(.v) == .press) {
            vsync = !vsync;
        }
        last_v = window.getKey(.v);
        last_d = window.getKey(.d);

        if (last_r != .press and window.getKey(.r) == .press) {
            if (buildProgram(init.io, init.environ_map, gpa_allocator, shaderc_path)) |program| {
                bgfx.destroyProgram(programHandle);
                programHandle = program;
            } else |err| {
                std.log.err("Build program failed => {}", .{err});
            }
        }
        last_r = window.getKey(.r);

        //
        // New flags?
        //
        reset_flags = bgfx.ResetFlags_None;
        if (vsync) {
            reset_flags |= bgfx.ResetFlags_Vsync;
        }

        //
        // Show debug
        //
        if (debug) {
            bgfx.setDebug(bgfx.DebugFlags_Stats);
        } else {
            bgfx.setDebug(bgfx.DebugFlags_None);
        }

        //
        // If resolution or flags is changed set new matrix and reset.
        //
        const size = window.getFramebufferSize();
        if (old_flags != reset_flags or old_size[0] != size[0] or old_size[1] != size[1]) {
            const aspect_ratio = @as(f32, @floatFromInt(size[0])) / @as(f32, @floatFromInt(size[1]));
            projMtx = zm.perspectiveFovRhGl(
                0.25 * math.pi,
                aspect_ratio,
                0.1,
                100.0,
            );

            bgfx.reset(
                @intCast(size[0]),
                @intCast(size[1]),
                reset_flags,
                bgfx_init.resolution.formatColor,
            );
            old_size = size;
            old_flags = reset_flags;
        }

        //
        //  Preapare view
        //
        bgfx.setViewTransform(0, &zm.matToArr(viewMtx), &zm.matToArr(projMtx));
        bgfx.setViewRect(0, 0, 0, @intCast(size[0]), @intCast(size[1]));
        bgfx.touch(0);
        bgfx.dbgTextClear(0, false);

        //
        //  Render cubes
        //
        var yy: f32 = 0;

        const time: f32 = @as(f32, @floatFromInt(start.untilNow(init.io, .awake).toMilliseconds())) / std.time.ms_per_s;
        while (yy < 11) : (yy += 1.0) {
            var xx: f32 = 0;
            while (xx < 11) : (xx += 1.0) {
                const trans = zm.translation(-15.0 + xx * 3.0, -15 + yy * 3.0, 3.0 * @sin(3.0 * time + xx + yy));
                const rotX = zm.rotationX(@sin(1.5 * time) + xx * 0.21);
                const rotY = zm.rotationY(@sin(1.5 * time) + yy * 0.37);
                const rotXY = zm.mul(rotX, rotY);
                const modelMtx = zm.mul(rotXY, trans);

                _ = bgfx.setTransform(&zm.matToArr(modelMtx), 1);
                bgfx.setVertexBuffer(0, vbh, 0, cube_vertices.len);
                bgfx.setIndexBuffer(ibh, 0, cube_tri_list.len);
                bgfx.setState(state, 0);
                bgfx.submit(0, programHandle, 0, 255);
            }
        }

        // Render Frame
        _ = bgfx.frame(0);
    }

    return 0;
}

fn readFileFromShaderDirs(io: std.Io, allocator: std.mem.Allocator, filename: []const u8) ![]u8 {
    const exe_dir = try std.process.executableDirPathAlloc(io, allocator);
    defer allocator.free(exe_dir);

    const path = try std.fs.path.join(allocator, &.{ exe_dir, "shaders", filename });
    defer allocator.free(path);

    const f = try std.Io.Dir.cwd().openFile(io, path, .{});
    defer f.close(io);
    const max_size = (try f.length(io)) + 1;

    var buffer: [1024]u8 = undefined;
    var reader = f.reader(io, &buffer);
    var r = &reader.interface;
    return try r.readAlloc(allocator, max_size - 1);
}

// https://github.com/liyu1981/tmpfile.zig/blob/master/src/tmpfile.zig#L11
pub fn getSysTmpDir(a: std.mem.Allocator, env_map: *const std.process.Environ.Map) ![]const u8 {
    const Impl = switch (builtin.os.tag) {
        .linux, .macos => struct {
            pub fn get(allocator: std.mem.Allocator, env_map_: *const std.process.Environ.Map) ![]const u8 {
                // cpp17's temp_directory_path gives good reference
                // https://en.cppreference.com/w/cpp/filesystem/temp_directory_path
                // POSIX standard, https://en.wikipedia.org/wiki/TMPDIR
                return allocator.dupe(
                    u8,
                    env_map_.get("TMPDIR") orelse
                        env_map_.get("TMP") orelse
                        env_map_.get("TEMP") orelse
                        env_map_.get("TEMPDIR") orelse
                        "/tmp",
                );
            }
        },
        .windows => struct {
            const DWORD = std.os.windows.DWORD;
            const LPWSTR = std.os.windows.LPWSTR;
            const MAX_PATH = std.os.windows.MAX_PATH;
            const WCHAR = std.os.windows.WCHAR;

            pub extern "C" fn GetTempPath2W(BufferLength: DWORD, Buffer: LPWSTR) DWORD;

            pub fn get(allocator: std.mem.Allocator, env_map_: *const std.process.Environ.Map) ![]const u8 {
                _ = env_map_;
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

    return Impl.get(a, env_map);
}
