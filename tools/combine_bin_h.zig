const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allcator = gpa.allocator();

    const args = try std.process.argsAlloc(allcator);
    defer std.process.argsFree(allcator, args);

    if (args.len < 4) fatal("wrong number of arguments {d}", .{args.len});

    const name = args[1];
    const output_file_path = args[2];
    var output_file = std.fs.cwd().createFile(output_file_path, .{}) catch |err| {
        fatal("unable to open '{s}': {s}", .{ output_file_path, @errorName(err) });
    };
    defer output_file.close();

    var it: u32 = 3;
    while (it < args.len) : (it += 1) {
        const path = args[it];

        var f = try std.fs.cwd().openFile(path, .{});
        defer f.close();
        try output_file.writeFileAll(f, .{});
    }

    var w = output_file.writer();
    try w.print("extern const uint8_t* {s}_pssl;\n", .{name});
    try w.print("extern const uint32_t {s}_pssl_size;\n", .{name});
}

fn fatal(comptime format: []const u8, args: anytype) noreturn {
    std.debug.print(format, args);
    std.process.exit(1);
}
