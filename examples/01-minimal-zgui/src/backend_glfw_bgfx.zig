const zgui = @import("zgui");

const zbgfx = @import("zbgfx");
const backend_bgfx = zbgfx.imgui_backend;

pub fn init(
    window: ?*const anyopaque, // zglfw.Window
) void {
    if (window) |w| {
        zgui.backend.init(w);
    }

    backend_bgfx.init();
}

pub fn deinit() void {
    backend_bgfx.deinit();
    zgui.backend.deinit();
}

pub fn newFrame(fb_width: u32, fb_height: u32) void {
    var w = fb_width;
    var h = fb_height;

    // Headless mode
    // Set some default imgui screen size
    if (fb_width == 0 and fb_height == 0) {
        w = 1024;
        h = 768;
    }

    zgui.io.setDisplaySize(@floatFromInt(w), @floatFromInt(h));
    zgui.io.setDisplayFramebufferScale(1.0, 1.0);

    zgui.backend.newFrame();
    backend_bgfx.newFrame(@truncate(fb_width), @truncate(fb_height), 255);
}

pub fn draw() void {
    zgui.render();
    backend_bgfx.draw();
}
