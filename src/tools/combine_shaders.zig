const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());

    if (args.len < 3) fatal("wrong number of arguments {d}", .{args.len});

    const output_file_path = args[1];
    var output_file = std.Io.Dir.cwd().createFile(init.io, output_file_path, .{}) catch |err| {
        fatal("unable to open '{s}': {s}", .{ output_file_path, @errorName(err) });
    };
    defer output_file.close(init.io);

    var buffer: [1024]u8 = undefined;
    var writer = output_file.writer(init.io, &buffer);
    var w = &writer.interface;
    defer w.flush() catch undefined;

    try w.print("//\n", .{});
    try w.print("// GENERATED - DO NOT EDIT\n", .{});
    try w.print("//\n\n", .{});

    var it: u32 = 2;
    while (it < args.len) : (it += 1) {
        const path = args[it];
        try w.print("pub const {s} = @import(\"{s}\");\n", .{ path, path });
    }
}

fn fatal(comptime format: []const u8, args: anytype) noreturn {
    std.debug.print(format, args);
    std.process.exit(1);
}
