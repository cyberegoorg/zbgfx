const std = @import("std");
const shaderc = @import("shaderc.zig");

pub fn main() anyerror!u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa_allocator = gpa.allocator();
    defer _ = gpa.deinit();
    const args = try std.process.argsAlloc(gpa_allocator);
    defer std.process.argsFree(gpa_allocator, args);

    var c_args = std.ArrayList([*:0]const u8).init(gpa_allocator);
    defer c_args.deinit();

    for (args) |arg| {
        try c_args.append((arg.ptr));
    }

    return @intCast(shaderc.shaderc_main(@intCast(args.len), c_args.items.ptr));
}
