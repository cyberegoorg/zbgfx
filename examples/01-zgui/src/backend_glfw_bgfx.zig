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

pub fn newFrame(viewid: zbgfx.bgfx.ViewId) void {
    zgui.backend.newFrame();
    backend_bgfx.newFrame(viewid);
}

pub fn draw() void {
    zgui.render();
    backend_bgfx.draw();
}
