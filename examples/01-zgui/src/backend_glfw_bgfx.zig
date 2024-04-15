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
    const w = fb_width;
    const h = fb_height;

    zgui.backend.newFrame();

    zgui.io.setDisplaySize(@floatFromInt(w), @floatFromInt(h));
    zgui.io.setDisplayFramebufferScale(1.0, 1.0);

    backend_bgfx.newFrame(255);
}

pub fn draw() void {
    zgui.render();
    backend_bgfx.draw();
}
