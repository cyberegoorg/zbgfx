const bgfx = @import("bgfx");

pub fn init() void {
    ImGui_ImplBgfx_Init();
}

pub fn deinit() void {
    ImGui_ImplBgfx_Shutdown();
}

pub fn newFrame(viewid: bgfx.ViewId) void {
    ImGui_ImplBgfx_NewFrame(viewid);
}

pub fn draw() void {
    ImGui_ImplBgfx_RenderDrawData();
}

extern fn ImGui_ImplBgfx_Init() void;
extern fn ImGui_ImplBgfx_Shutdown() void;
extern fn ImGui_ImplBgfx_NewFrame(_viewId: bgfx.ViewId) void;
extern fn ImGui_ImplBgfx_RenderDrawData() void;
