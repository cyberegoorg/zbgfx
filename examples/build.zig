const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    try @import("minimal-glfw/build_sample.zig").build(b, optimize, target);
    try @import("shader-runtime/build_sample.zig").build(b, optimize, target);
    try @import("shader-embed/build_sample.zig").build(b, optimize, target);
    try @import("zgui/build_sample.zig").build(b, optimize, target);
    try @import("debugdraw/build_sample.zig").build(b, optimize, target);
}
