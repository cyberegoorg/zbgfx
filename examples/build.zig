const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    try @import("00-minimal/build_sample.zig").build(b, optimize, target);
    try @import("01-zgui/build_sample.zig").build(b, optimize, target);
    try @import("02-runtime-shaderc/build_sample.zig").build(b, optimize, target);
    try @import("03-debugdraw/build_sample.zig").build(b, optimize, target);
}
