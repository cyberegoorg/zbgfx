const std = @import("std");

fn prefixToPlatform(prefix: []const u8) []const u8 {
    if (std.mem.eql(u8, prefix, "dx11")) return "Direct3D12";
    if (std.mem.eql(u8, prefix, "mtl")) return "Metal";
    if (std.mem.eql(u8, prefix, "spv")) return "Vulkan";
    if (std.mem.eql(u8, prefix, "essl")) return "OpenGLES";
    if (std.mem.eql(u8, prefix, "glsl")) return "OpenGL";
    return undefined;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allcator = gpa.allocator();

    const args = try std.process.argsAlloc(allcator);
    defer std.process.argsFree(allcator, args);

    if (args.len < 3) fatal("wrong number of arguments {d}", .{args.len});

    const output_file_path = args[1];
    var output_file = std.fs.cwd().createFile(output_file_path, .{}) catch |err| {
        fatal("unable to open '{s}': {s}", .{ output_file_path, @errorName(err) });
    };
    defer output_file.close();

    var w = output_file.writer();

    try w.print("//\n", .{});
    try w.print("// GENERATED - DO NOT EDIT\n", .{});
    try w.print("//\n\n", .{});

    try w.print("const zbgfx = @import(\"zbgfx\");\n", .{});
    try w.print("const bgfx = zbgfx.bgfx;\n\n", .{});

    var it: u32 = 2;
    while (it < args.len) : (it += 1) {
        const path = args[it];
        try w.print("const {s} = @embedFile(\"{s}\");\n", .{ path, path });
    }

    const get_fce =
        \\
        \\pub fn getShaderForRenderer(renderer: bgfx.RendererType) [*c]const bgfx.Memory {
        \\    const data = switch (renderer) {
    ;

    const get_fce2 =
        \\        else => undefined,
        \\    };
        \\    
        \\    return bgfx.makeRef(data.ptr, @truncate(data.len));
        \\}
    ;

    try w.print("{s}\n", .{get_fce});
    var it2: u32 = 2;
    while (it2 < args.len) : (it2 += 1) {
        const path = args[it2];
        const renderer = prefixToPlatform(path);

        try w.print("      .{s} => {s},\n", .{ renderer, path });
    }
    try w.print("{s}\n", .{get_fce2});
}

fn fatal(comptime format: []const u8, args: anytype) noreturn {
    std.debug.print(format, args);
    std.process.exit(1);
}
