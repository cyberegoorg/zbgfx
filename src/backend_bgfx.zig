const bgfx = @import("bgfx.zig");

pub fn init() void {
    ImGui_ImplBgfx_Init();
}

pub fn deinit() void {
    ImGui_ImplBgfx_Shutdown();
}

pub fn newFrame(fb_width: u32, fb_height: u32, viewid: bgfx.ViewId) void {
    ImGui_ImplBgfx_NewFrame(@truncate(fb_width), @truncate(fb_height), viewid);
}

pub fn draw() void {
    ImGui_ImplBgfx_RenderDrawData();
}

extern fn ImGui_ImplBgfx_Init() void;
extern fn ImGui_ImplBgfx_Shutdown() void;
extern fn ImGui_ImplBgfx_NewFrame(_width: u16, _height: u16, _viewId: bgfx.ViewId) void;
extern fn ImGui_ImplBgfx_RenderDrawData() void;
