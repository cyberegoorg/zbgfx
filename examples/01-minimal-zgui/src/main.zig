const std = @import("std");
const builtin = @import("builtin");
const math = std.math;

const zglfw = @import("zglfw");
const zgui = @import("zgui");

const zbgfx = @import("zbgfx");
const bgfx = zbgfx.bgfx;

const backend_glfw_bgfx = @import("backend_glfw_bgfx.zig");

const WIDTH = 1280;
const HEIGHT = 720;

var bgfx_clbs = zbgfx.callbacks.CCallbackInterfaceT{
    .vtable = &zbgfx.callbacks.DefaultZigCallbackVTable.toVtbl(),
};
var bgfx_alloc: zbgfx.callbacks.ZigAllocator = undefined;

var debug = true;
var vsync = true;

var last_v = zglfw.Action.release;
var last_d = zglfw.Action.release;
var old_flags = bgfx.ResetFlags_None;
var old_size = [2]i32{ WIDTH, HEIGHT };

pub fn main() anyerror!u8 {
    //
    // Init zglfw
    //
    try zglfw.init();
    defer zglfw.terminate();

    //
    // Create window
    //
    zglfw.windowHintTyped(.client_api, .no_api);
    const window = try zglfw.Window.create(WIDTH, HEIGHT, "ZBgfx - minimal", null);
    defer window.destroy();
    window.setSizeLimits(400, 400, -1, -1);

    //
    // Init bgfx init params
    //
    var bgfx_init: bgfx.Init = undefined;
    bgfx.initCtor(&bgfx_init);

    // This force renderer type.
    // bgfx_init.type == .Vulkan

    bgfx_init.resolution.width = WIDTH;
    bgfx_init.resolution.height = HEIGHT;
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
            bgfx_init.platformData.type = bgfx.NativeWindowHandleType.Default;
            bgfx_init.platformData.nwh = @ptrFromInt(zglfw.getX11Window(window));
            bgfx_init.platformData.ndt = zglfw.getX11Display();
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

    var reset_flags = bgfx.ResetFlags_None;
    if (vsync) {
        reset_flags |= bgfx.ResetFlags_Vsync;
    }

    //
    // Reset and clear
    //
    bgfx.reset(WIDTH, HEIGHT, reset_flags, bgfx_init.resolution.format);

    // Set view 0 clear state.
    bgfx.setViewClear(0, bgfx.ClearFlags_Color | bgfx.ClearFlags_Depth, 0x303030ff, 1.0, 0);

    //
    // Default state
    //
    const state = 0 | bgfx.StateFlags_WriteRgb | bgfx.StateFlags_WriteA | bgfx.StateFlags_WriteZ | bgfx.StateFlags_DepthTestLess | bgfx.StateFlags_CullCcw | bgfx.StateFlags_Msaa;
    _ = state; // autofix

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa_allocator = gpa.allocator();
    defer _ = gpa.deinit();

    zgui.init(gpa_allocator);
    defer zgui.deinit();
    backend_glfw_bgfx.init(window);
    defer backend_glfw_bgfx.deinit();

    //
    // Main loop
    //
    const start_time: i64 = std.time.milliTimestamp();
    _ = start_time; // autofix
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
        // If resolution or flags is changed reset.
        //
        const size = window.getSize();
        if (old_flags != reset_flags or old_size[0] != size[0] or old_size[1] != size[1]) {
            bgfx.reset(
                @intCast(size[0]),
                @intCast(size[1]),
                reset_flags,
                bgfx_init.resolution.format,
            );
            old_size = size;
            old_flags = reset_flags;
        }

        bgfx.setViewRect(0, 0, 0, @intCast(size[0]), @intCast(size[1]));
        bgfx.touch(0);
        bgfx.dbgTextClear(0, false);

        // Do some zgui stuff
        backend_glfw_bgfx.newFrame(@intCast(size[0]), @intCast(size[1]));
        zgui.showDemoWindow(null);
        backend_glfw_bgfx.draw();

        // Render Frame
        _ = bgfx.frame(false);
    }

    return 0;
}
