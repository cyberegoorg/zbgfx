const std = @import("std");
const bgfx = @import("bgfx");
const builtin = @import("builtin");

const log = std.log.scoped(.bgfx);

const Self = @This();

//
// Allocator
// FIXME: Does not work because `panic: integer cast truncated bits` from true zig allocator.
//

pub const CAllocInterfaceT = extern struct { vtable: *const CAllocVtblT };
pub const CAllocVtblT = extern struct {
    realloc: *const fn (_this: *CAllocInterfaceT, _ptr: [*c]u8, _size: usize, _align: usize, _file: [*:0]const u8, _line: u32) callconv(.c) ?*anyopaque,
};

pub const ZigAllocatorVtbl = extern struct {
    fn realloc(_this: *CAllocInterfaceT, _ptr: [*c]u8, _size: usize, _align: usize, _file: [*:0]const u8, _line: u32) callconv(.c) ?*anyopaque {
        var self: *ZigAllocator = @ptrCast(_this);
        _ = _file; // autofix
        _ = _line; // autofix

        if (_size != 0) {
            return self.allocator.rawAlloc(_size, @truncate(_align), 0);
        }
        self.allocator.free(_ptr[0.._size]);
        return null;
    }
    pub fn toVtbl() Self.CAllocVtblT {
        return CAllocVtblT{ .realloc = @This().realloc };
    }
};

pub const ZigAllocator = extern struct {
    const _alloc_vtable = ZigAllocatorVtbl.toVtbl();
    vtable: ?*const CAllocVtblT = null,
    allocator: *std.mem.Allocator,

    pub fn init(alloc: *std.mem.Allocator) ZigAllocator {
        return .{ .vtable = &_alloc_vtable, .allocator = alloc };
    }
};

//
// Callbacks
//

// TODO: error on x86_64 windows because zig does not support valist on some platform
//pub const VaList = std.builtin.VaList;
pub const VaList = extern struct { _: *anyopaque }; // dirty&tricky is your best firends.
//

pub const CCallbackInterfaceT = extern struct { vtable: *const CCallbackVtblT };
pub const CCallbackVtblT = extern struct {
    fatal: *const fn (_this: *CCallbackInterfaceT, _filePath: [*:0]const u8, _line: u16, _code: bgfx.Fatal, c_str: [*:0]const u8) callconv(.c) void,
    trace_vargs: *const fn (_this: *CCallbackInterfaceT, _filePath: [*:0]const u8, _line: u16, _format: [*:0]const u8, va_list: VaList) callconv(.c) void,
    profiler_begin: *const fn (_this: *CCallbackInterfaceT, _name: [*:0]const u8, _abgr: u32, _filePath: [*:0]const u8, _line: u16) callconv(.c) void,
    profiler_begin_literal: *const fn (_this: *CCallbackInterfaceT, _name: [*:0]const u8, _abgr: u32, _filePath: [*:0]const u8, _line: u16) callconv(.c) void,
    profiler_end: *const fn (_this: *CCallbackInterfaceT) callconv(.c) void,
    cache_read_size: *const fn (_this: *CCallbackInterfaceT, _id: u64) callconv(.c) u32,
    cache_read: *const fn (_this: *CCallbackInterfaceT, _id: u64, _data: [*c]u8, _size: u32) callconv(.c) bool,
    cache_write: *const fn (_this: *CCallbackInterfaceT, _id: u64, _data: [*c]u8, _size: u32) callconv(.c) void,
    screen_shot: *const fn (_this: *CCallbackInterfaceT, _filePath: [*:0]const u8, _width: u32, _height: u32, _pitch: u32, _data: [*c]u8, _size: u32, _yflip: bool) callconv(.c) void,
    capture_begin: *const fn (_this: *CCallbackInterfaceT, _width: u32, _height: u32, _pitch: u32, _format: bgfx.TextureFormat, _yflip: bool) callconv(.c) void,
    capture_end: *const fn (_this: *CCallbackInterfaceT) callconv(.c) void,
    capture_frame: *const fn (_this: *CCallbackInterfaceT, _data: [*c]u8, _size: u32) callconv(.c) void,
};

pub const DefaultZigCallbackVTable = struct {
    pub fn fatal(_this: *CCallbackInterfaceT, _filePath: [*:0]const u8, _line: u16, _code: bgfx.Fatal, c_str: [*:0]const u8) callconv(.c) void {
        _ = _this;
        const cstr = std.mem.span(c_str);
        log.err("FATAL in {s}:{d}: {s} => {s}", .{ _filePath, _line, @tagName(_code), cstr });
    }
    pub fn trace_vargs(_this: *CCallbackInterfaceT, _filePath: [*:0]const u8, _line: u16, _format: [*:0]const u8, va_list: Self.VaList) callconv(.c) void {
        _ = _this;
        _ = _filePath;
        _ = _line;

        const bgfx_string = "BGFX ";

        var buff: [1024]u8 = undefined;
        const len = formatTrace(&buff, buff.len, _format, va_list);
        const msg = buff[bgfx_string.len .. @as(usize, @intCast(len)) - 1];

        log.debug("{s}", .{msg});
    }
    pub fn profiler_begin(_this: *Self.CCallbackInterfaceT, _name: [*:0]const u8, _abgr: u32, _filePath: [*:0]const u8, _line: u16) callconv(.c) void {
        _ = _this;
        _ = _name;
        _ = _abgr;
        _ = _filePath;
        _ = _line;
    }
    pub fn profiler_begin_literal(_this: *Self.CCallbackInterfaceT, _name: [*:0]const u8, _abgr: u32, _filePath: [*:0]const u8, _line: u16) callconv(.c) void {
        _ = _this;
        _ = _name;
        _ = _abgr;
        _ = _filePath;
        _ = _line;
    }
    pub fn profiler_end(_this: *Self.CCallbackInterfaceT) callconv(.c) void {
        _ = _this;
    }
    pub fn cache_read_size(_this: *Self.CCallbackInterfaceT, _id: u64) callconv(.c) u32 {
        _ = _this;
        _ = _id;
        return 0;
    }
    pub fn cache_read(_this: *Self.CCallbackInterfaceT, _id: u64, _data: [*c]u8, _size: u32) callconv(.c) bool {
        _ = _this;
        _ = _id;
        _ = _data;
        _ = _size;
        return false;
    }
    pub fn cache_write(_this: *Self.CCallbackInterfaceT, _id: u64, _data: [*c]u8, _size: u32) callconv(.c) void {
        _ = _this;
        _ = _id;
        _ = _data;
        _ = _size;
    }
    pub fn screen_shot(_this: *Self.CCallbackInterfaceT, _filePath: [*:0]const u8, _width: u32, _height: u32, _pitch: u32, _data: [*c]u8, _size: u32, _yflip: bool) callconv(.c) void {
        _ = _this;
        _ = _filePath;
        _ = _width;
        _ = _height;
        _ = _pitch;
        _ = _data;
        _ = _size;
        _ = _yflip;
    }
    pub fn capture_begin(_this: *Self.CCallbackInterfaceT, _width: u32, _height: u32, _pitch: u32, _format: bgfx.TextureFormat, _yflip: bool) callconv(.c) void {
        _ = _this;
        _ = _width;
        _ = _height;
        _ = _pitch;
        _ = _format;
        _ = _yflip;
        log.warn("{s}", .{"Using capture without callback (a.k.a. pointless)."});
    }
    pub fn capture_end(_this: *Self.CCallbackInterfaceT) callconv(.c) void {
        _ = _this;
    }
    pub fn capture_frame(_this: *Self.CCallbackInterfaceT, _data: [*c]u8, _size: u32) callconv(.c) void {
        _ = _this;
        _ = _data;
        _ = _size;
    }

    pub fn toVtbl() Self.CCallbackVtblT {
        return Self.CCallbackVtblT{
            .fatal = @This().fatal,
            .trace_vargs = @This().trace_vargs,
            .profiler_begin = @This().profiler_begin,
            .profiler_begin_literal = @This().profiler_begin_literal,
            .profiler_end = @This().profiler_end,
            .cache_read_size = @This().cache_read_size,
            .cache_read = @This().cache_read,
            .cache_write = @This().cache_write,
            .screen_shot = @This().screen_shot,
            .capture_begin = @This().capture_begin,
            .capture_end = @This().capture_end,
            .capture_frame = @This().capture_frame,
        };
    }
};

extern fn formatTrace(buff: [*]const u8, buff_size: u32, _format: [*:0]const u8, _argList: VaList) i32;
