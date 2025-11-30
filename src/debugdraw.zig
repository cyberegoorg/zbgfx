const std = @import("std");
const bgfx = @import("bgfx");

pub const Axis = enum(c_int) {
    X,
    Y,
    Z,
    Count,
};

pub const Vertex = extern struct {
    x: f32,
    y: f32,
    z: f32,
};

pub const SpriteHandle = extern struct {
    idx: u16,

    fn isValid(sprite: SpriteHandle) bool {
        return sprite.idx != std.math.maxInt(u16);
    }
};

pub const GeometryHandle = extern struct {
    idx: u16,

    fn isValid(geometry: GeometryHandle) bool {
        return geometry.idx != std.math.maxInt(u16);
    }
};

pub fn init() void {
    zbgfx_ddInit();
}
extern fn zbgfx_ddInit() void;

pub fn deinit() void {
    zbgfx_ddShutdown();
}
extern fn zbgfx_ddShutdown() void;

//
// Sprite
//
pub fn createSprite(width: u16, height: u16, _data: []const u8) SpriteHandle {
    return zbgfx_ddCreateSprite(width, height, _data.ptr);
}
extern fn zbgfx_ddCreateSprite(_width: u16, _height: u16, _data: [*]const u8) SpriteHandle;

pub fn destroySprite(handle: SpriteHandle) void {
    return zbgfx_ddDestroySprite(handle);
}
extern fn zbgfx_ddDestroySprite(_handle: SpriteHandle) void;

//
// Geometry
//
pub fn createGeometry(numVertices: u32, vertices: []const Vertex, numIndices: u32, indices: ?[*]const u8, index32: bool) GeometryHandle {
    return zbgfx_ddCreateGeometry(numVertices, vertices.ptr, numIndices, indices.?, index32);
}
extern fn zbgfx_ddCreateGeometry(_numVertices: u32, _vertices: [*]const Vertex, _numIndices: u32, _indices: ?[*]const u8, _index32: bool) GeometryHandle;

pub fn destroyGeometry(handle: GeometryHandle) void {
    return zbgfx_ddDestroyGeometry(handle);
}
extern fn zbgfx_ddDestroyGeometry(_handle: GeometryHandle) void;

// Encoder
pub const Encoder = opaque {
    //
    pub fn create() *Encoder {
        return zbgfx_createEncoder();
    }
    extern fn zbgfx_createEncoder() *Encoder;

    //
    pub fn destroy(encoder: *Encoder) void {
        zbgfx_destroyEncoder(encoder);
    }
    extern fn zbgfx_destroyEncoder(encoder: *Encoder) void;

    //
    pub fn begin(dde: *Encoder, _viewId: u16, _depthTestLess: bool, _encoder: ?*bgfx.Encoder) void {
        zbgfx_EncoderBegin(dde, _viewId, _depthTestLess, _encoder);
    }
    extern fn zbgfx_EncoderBegin(dde: *Encoder, _viewId: u16, _depthTestLess: bool, _encoder: ?*bgfx.Encoder) void;

    //
    pub fn end(dde: *Encoder) void {
        zbgfx_EncoderEnd(dde);
    }
    extern fn zbgfx_EncoderEnd(dde: *Encoder) void;

    //
    pub fn push(dde: *Encoder) void {
        zbgfx_EncoderPush(dde);
    }
    extern fn zbgfx_EncoderPush(dde: *Encoder) void;

    //
    pub fn pop(dde: *Encoder) void {
        zbgfx_EncoderPop(dde);
    }
    extern fn zbgfx_EncoderPop(dde: *Encoder) void;

    //
    pub fn setDepthTestLess(dde: *Encoder, _depthTestLess: bool) void {
        zbgfx_EncoderSetDepthTestLess(dde, _depthTestLess);
    }
    extern fn zbgfx_EncoderSetDepthTestLess(dde: *Encoder, _depthTestLess: bool) void;

    //
    pub fn setState(dde: *Encoder, _depthTest: bool, _depthWrite: bool, _clockwise: bool) void {
        zbgfx_EncoderSetState(dde, _depthTest, _depthWrite, _clockwise);
    }
    extern fn zbgfx_EncoderSetState(dde: *Encoder, _depthTest: bool, _depthWrite: bool, _clockwise: bool) void;

    //
    pub fn setColor(dde: *Encoder, _abgr: u32) void {
        zbgfx_EncoderSetColor(dde, _abgr);
    }
    extern fn zbgfx_EncoderSetColor(dde: *Encoder, _abgr: u32) void;

    //
    pub fn setLod(dde: *Encoder, _lod: u8) void {
        zbgfx_EncoderSetLod(dde, _lod);
    }
    extern fn zbgfx_EncoderSetLod(dde: *Encoder, _lod: u8) void;

    //
    pub fn setWireframe(dde: *Encoder, _wireframe: bool) void {
        zbgfx_EncoderSetWireframe(dde, _wireframe);
    }
    extern fn zbgfx_EncoderSetWireframe(dde: *Encoder, _wireframe: bool) void;

    //
    pub fn setStipple(dde: *Encoder, _stipple: bool, _scale: f32, _offset: f32) void {
        zbgfx_EncoderSetStipple(dde, _stipple, _scale, _offset);
    }
    extern fn zbgfx_EncoderSetStipple(dde: *Encoder, _stipple: bool, _scale: f32, _offset: f32) void;

    //
    pub fn setSpin(dde: *Encoder, _spin: f32) void {
        zbgfx_EncoderSetSpin(dde, _spin);
    }
    extern fn zbgfx_EncoderSetSpin(dde: *Encoder, _spin: f32) void;

    //
    pub fn setTransform(dde: *Encoder, _mtx: ?*const anyopaque) void {
        zbgfx_EncoderSetTransform(dde, _mtx);
    }
    extern fn zbgfx_EncoderSetTransform(dde: *Encoder, _mtx: ?*const anyopaque) void;

    //
    pub fn setTranslate(dde: *Encoder, _xyz: [3]f32) void {
        zbgfx_EncoderSetTranslate(dde, _xyz[0], _xyz[1], _xyz[2]);
    }
    extern fn zbgfx_EncoderSetTranslate(dde: *Encoder, _x: f32, _y: f32, _z: f32) void;

    //
    pub fn pushTransform(dde: *Encoder, _mtx: *anyopaque) void {
        zbgfx_EncoderPushTransform(dde, _mtx);
    }
    extern fn zbgfx_EncoderPushTransform(dde: *Encoder, _mtx: *anyopaque) void;

    //
    pub fn popTransform(dde: *Encoder) void {
        zbgfx_EncoderPopTransform(dde);
    }
    extern fn zbgfx_EncoderPopTransform(dde: *Encoder) void;

    //
    pub fn moveTo(dde: *Encoder, _xyz: [3]f32) void {
        zbgfx_EncoderMoveTo(dde, _xyz[0], _xyz[1], _xyz[2]);
    }
    extern fn zbgfx_EncoderMoveTo(dde: *Encoder, _x: f32, _y: f32, _z: f32) void;

    //
    pub fn lineTo(dde: *Encoder, _xyz: [3]f32) void {
        zbgfx_EncoderLineTo(dde, _xyz[0], _xyz[1], _xyz[2]);
    }
    extern fn zbgfx_EncoderLineTo(dde: *Encoder, _x: f32, _y: f32, _z: f32) void;

    //
    pub fn close(dde: *Encoder) void {
        zbgfx_EncoderClose(dde);
    }
    extern fn zbgfx_EncoderClose(dde: *Encoder) void;

    ///
    pub fn drawAABB(dde: *Encoder, min: [3]f32, max: [3]f32) void {
        zbgfx_EncoderDrawAABB(dde, @ptrCast(&min), @ptrCast(&max));
    }
    extern fn zbgfx_EncoderDrawAABB(dde: *Encoder, min: [*]const f32, max: [*]const f32) void;

    ///
    pub fn drawCylinder(dde: *Encoder, pos: [3]f32, _end: [3]f32, radius: f32) void {
        zbgfx_EncoderDrawCylinder(dde, @ptrCast(&pos), @ptrCast(&_end), radius);
    }
    extern fn zbgfx_EncoderDrawCylinder(dde: *Encoder, pos: [*]const f32, end: [*]const f32, radius: f32) void;

    ///
    pub fn drawCapsule(dde: *Encoder, pos: [3]f32, _end: [3]f32, radius: f32) void {
        zbgfx_EncoderDrawCapsule(dde, @ptrCast(&pos), @ptrCast(&_end), radius);
    }
    extern fn zbgfx_EncoderDrawCapsule(dde: *Encoder, pos: [*]const f32, end: [*]const f32, radius: f32) void;

    ///
    pub fn drawDisk(dde: *Encoder, center: [3]f32, normal: [3]f32, radius: f32) void {
        zbgfx_EncoderDrawDisk(dde, @ptrCast(&center), @ptrCast(&normal), radius);
    }
    extern fn zbgfx_EncoderDrawDisk(dde: *Encoder, center: [*]const f32, normal: [*]const f32, radius: f32) void;

    ///
    pub fn drawObb(dde: *Encoder, _obb: [3]f32) void {
        zbgfx_EncoderDrawObb(dde, @ptrCast(&_obb));
    }
    extern fn zbgfx_EncoderDrawObb(dde: *Encoder, _obb: [*]const f32) void;

    ///
    pub fn drawSphere(dde: *Encoder, center: [3]f32, radius: f32) void {
        zbgfx_EncoderDrawSphere(dde, @ptrCast(&center), radius);
    }
    extern fn zbgfx_EncoderDrawSphere(dde: *Encoder, center: [*]const f32, radius: f32) void;

    ///
    pub fn drawTriangle(dde: *Encoder, v0: [3]f32, v1: [3]f32, v2: [3]f32) void {
        zbgfx_EncoderDrawTriangle(dde, @ptrCast(&v0), @ptrCast(&v1), @ptrCast(&v2));
    }
    extern fn zbgfx_EncoderDrawTriangle(dde: *Encoder, v0: [*]const f32, v1: [*]const f32, v2: [*]const f32) void;

    ///
    pub fn drawCone(dde: *Encoder, pos: [3]f32, _end: [3]f32, radius: f32) void {
        zbgfx_EncoderDrawCone(dde, @ptrCast(&pos), @ptrCast(&_end), radius);
    }
    extern fn zbgfx_EncoderDrawCone(dde: *Encoder, pos: [*]const f32, end: [*]const f32, radius: f32) void;

    //
    pub fn drawGeometry(dde: *Encoder, _handle: GeometryHandle) void {
        zbgfx_EncoderDrawGeometry(dde, _handle);
    }
    extern fn zbgfx_EncoderDrawGeometry(dde: *Encoder, _handle: GeometryHandle) void;

    ///
    pub fn drawLineList(Dde: *Encoder, _numVertices: u32, _vertices: []const Vertex, _numIndices: u32, _indices: ?[*]const u16) void {
        zbgfx_EncoderDrawLineList(Dde, _numVertices, _vertices.ptr, _numIndices, _indices);
    }
    extern fn zbgfx_EncoderDrawLineList(Dde: *Encoder, _numVertices: u32, _vertices: [*]const Vertex, _numIndices: u32, _indices: ?[*]const u16) void;

    ///
    pub fn drawTriList(Dde: *Encoder, _numVertices: u32, _vertices: []const Vertex, _numIndices: u32, _indices: ?[*]const u16) void {
        zbgfx_EncoderDrawTriList(Dde, _numVertices, _vertices.ptr, _numIndices, _indices.?);
    }
    extern fn zbgfx_EncoderDrawTriList(Dde: *Encoder, _numVertices: u32, _vertices: [*]const Vertex, _numIndices: u32, _indices: ?[*]const u16) void;

    ///
    pub fn drawFrustum(Dde: *Encoder, _viewProj: []f32) void {
        zbgfx_EncoderDrawFrustum(Dde, _viewProj.ptr);
    }
    extern fn zbgfx_EncoderDrawFrustum(Dde: *Encoder, _viewProj: [*]f32) void;

    ///
    pub fn drawArc(Dde: *Encoder, _axis: Axis, _xyz: [3]f32, _radius: f32, _degrees: f32) void {
        zbgfx_EncoderDrawArc(Dde, _axis, _xyz[0], _xyz[1], _xyz[2], _radius, _degrees);
    }
    extern fn zbgfx_EncoderDrawArc(Dde: *Encoder, _axis: Axis, _x: f32, _y: f32, _z: f32, _radius: f32, _degrees: f32) void;

    ///
    pub fn drawCircle(Dde: *Encoder, _normal: [3]f32, _center: [3]f32, _radius: f32, _weight: f32) void {
        zbgfx_EncoderDrawCircle(Dde, &_normal, &_center, _radius, _weight);
    }
    extern fn zbgfx_EncoderDrawCircle(Dde: *Encoder, _normal: [*]const f32, _center: [*]const f32, _radius: f32, _weight: f32) void;

    ///
    pub fn drawCircleAxis(Dde: *Encoder, _axis: Axis, _xyz: [3]f32, _radius: f32, _weight: f32) void {
        zbgfx_EncoderDrawCircleAxis(Dde, _axis, _xyz[0], _xyz[1], _xyz[2], _radius, _weight);
    }
    extern fn zbgfx_EncoderDrawCircleAxis(Dde: *Encoder, _axis: Axis, _x: f32, _y: f32, _z: f32, _radius: f32, _weight: f32) void;

    ///
    pub fn drawQuad(Dde: *Encoder, _normal: [3]f32, _center: [3]f32, _size: f32) void {
        zbgfx_EncoderDrawQuad(Dde, &_normal, &_center, _size);
    }
    extern fn zbgfx_EncoderDrawQuad(Dde: *Encoder, _normal: [*]const f32, _center: [*]const f32, _size: f32) void;

    ///
    pub fn drawQuadSprite(Dde: *Encoder, _handle: SpriteHandle, _normal: [3]f32, _center: [3]f32, _size: f32) void {
        zbgfx_EncoderDrawQuadSprite(Dde, _handle, &_normal, &_center, _size);
    }
    extern fn zbgfx_EncoderDrawQuadSprite(Dde: *Encoder, _handle: SpriteHandle, _normal: [*]const f32, _center: [*]const f32, _size: f32) void;

    ///
    pub fn drawQuadTexture(Dde: *Encoder, _handle: bgfx.TextureHandle, _normal: [3]f32, _center: [3]f32, _size: f32) void {
        zbgfx_EncoderDrawQuadTexture(Dde, _handle, &_normal, &_center, _size);
    }
    extern fn zbgfx_EncoderDrawQuadTexture(Dde: *Encoder, _handle: bgfx.TextureHandle, _normal: [*]const f32, _center: [*]const f32, _size: f32) void;

    ///
    pub fn drawAxis(Dde: *Encoder, _xyz: [3]f32, _len: f32, _highlight: Axis, _thickness: f32) void {
        zbgfx_EncoderDrawAxis(Dde, _xyz[0], _xyz[1], _xyz[2], _len, _highlight, _thickness);
    }
    extern fn zbgfx_EncoderDrawAxis(Dde: *Encoder, _x: f32, _y: f32, _z: f32, _len: f32, _highlight: Axis, _thickness: f32) void;

    ///
    pub fn drawGrid(Dde: *Encoder, _normal: [3]f32, _center: [3]f32, _size: u32, _step: f32) void {
        zbgfx_EncoderDrawGrid(Dde, &_normal, &_center, _size, _step);
    }
    extern fn zbgfx_EncoderDrawGrid(Dde: *Encoder, _normal: [*]const f32, _center: [*]const f32, _size: u32, _step: f32) void;

    ///
    pub fn drawGridAxis(Dde: *Encoder, _axis: Axis, _center: [3]f32, _size: u32, _step: f32) void {
        zbgfx_EncoderDrawGridAxis(Dde, _axis, &_center, _size, _step);
    }
    extern fn zbgfx_EncoderDrawGridAxis(Dde: *Encoder, _axis: Axis, _center: [*]const f32, _size: u32, _step: f32) void;

    ///
    pub fn drawOrb(Dde: *Encoder, _xyz: [3]f32, _radius: f32, _highlight: Axis) void {
        zbgfx_EncoderDrawOrb(Dde, _xyz[0], _xyz[1], _xyz[2], _radius, _highlight);
    }
    extern fn zbgfx_EncoderDrawOrb(Dde: *Encoder, _x: f32, _y: f32, _z: f32, _radius: f32, _highlight: Axis) void;
};
