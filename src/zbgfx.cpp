#include <bx/bx.h>
#include <bx/string.h>

#include "../libs/bgfx/examples/common/debugdraw/debugdraw.h"

extern "C"
{
    int32_t formatTrace(char *buff, uint32_t buff_size, const char *_format, va_list _argList)
    {
        char *out = buff;
        va_list argListCopy;
        int32_t total = bx::vsnprintf(out, buff_size, _format, _argList);
        return total;
    }

    //
    // Debug draw
    //
    void zbgfx_ddInit()
    {
        ddInit();
    }

    void zbgfx_ddShutdown()
    {
        ddShutdown();
    }

    SpriteHandle zbgfx_ddCreateSprite(uint16_t _width, uint16_t _height, const void *_data)
    {
        return ddCreateSprite(_width, _height, _data);
    }
    void zbgfx_ddDestroySprite(SpriteHandle _handle)
    {
        ddDestroy(_handle);
    }
    GeometryHandle zbgfx_ddCreateGeometry(uint32_t _numVertices, const DdVertex *_vertices, uint32_t _numIndices = 0, const void *_indices = NULL, bool _index32 = false)
    {
        return ddCreateGeometry(_numVertices, _vertices, _numIndices, _indices, _index32);
    }
    void zbgfx_ddDestroyGeometry(GeometryHandle _handle)
    {
        ddDestroy(_handle);
    }

    DebugDrawEncoder *zbgfx_createEncoder()
    {
        DebugDrawEncoder *dde = new DebugDrawEncoder();
        return dde;
    }

    void zbgfx_destroyEncoder(DebugDrawEncoder *dde)
    {
        delete dde;
    }

    ///
    void zbgfx_EncoderBegin(DebugDrawEncoder *dde, uint16_t _viewId, bool _depthTestLess = true, bgfx::Encoder *_encoder = NULL)
    {
        dde->begin(_viewId, _depthTestLess, _encoder);
    }

    ///
    void zbgfx_EncoderEnd(DebugDrawEncoder *dde)
    {
        dde->end();
    }

    ///
    void zbgfx_EncoderPush(DebugDrawEncoder *dde)
    {
        dde->push();
    }

    ///
    void zbgfx_EncoderPop(DebugDrawEncoder *dde)
    {
        dde->pop();
    }

    ///
    void zbgfx_EncoderSetDepthTestLess(DebugDrawEncoder *dde, bool _depthTestLess)
    {
        dde->setDepthTestLess(_depthTestLess);
    }

    ///
    void zbgfx_EncoderSetState(DebugDrawEncoder *dde, bool _depthTest, bool _depthWrite, bool _clockwise)
    {
        dde->setState(_depthTest, _depthWrite, _clockwise);
    }

    ///
    void zbgfx_EncoderSetColor(DebugDrawEncoder *dde, uint32_t _abgr)
    {
        dde->setColor(_abgr);
    }

    ///
    void zbgfx_EncoderSetLod(DebugDrawEncoder *dde, uint8_t _lod)
    {
        dde->setLod(_lod);
    }

    ///
    void zbgfx_EncoderSetWireframe(DebugDrawEncoder *dde, bool _wireframe)
    {
        dde->setWireframe(_wireframe);
    }

    ///
    void zbgfx_EncoderSetStipple(DebugDrawEncoder *dde, bool _stipple, float _scale = 1.0f, float _offset = 0.0f)
    {
        dde->setStipple(_stipple, _scale, _offset);
    }

    ///
    void zbgfx_EncoderSetSpin(DebugDrawEncoder *dde, float _spin)
    {
        dde->setSpin(_spin);
    }

    ///
    void zbgfx_EncoderSetTransform(DebugDrawEncoder *dde, const void *_mtx)
    {
        dde->setTransform(_mtx);
    }

    ///
    void zbgfx_EncoderSetTranslate(DebugDrawEncoder *dde, float _x, float _y, float _z)
    {
        dde->setTranslate(_x, _y, _z);
    }

    ///
    void zbgfx_EncoderPushTransform(DebugDrawEncoder *dde, const void *_mtx)
    {
        dde->pushTransform(_mtx);
    }

    ///
    void zbgfx_EncoderPopTransform(DebugDrawEncoder *dde)
    {
        dde->popTransform();
    }

    ///
    void zbgfx_EncoderMoveTo(DebugDrawEncoder *dde, float _x, float _y, float _z = 0.0f)
    {
        dde->moveTo(_x, _y, _z);
    }

    ///
    void zbgfx_EncoderLineTo(DebugDrawEncoder *dde, float _x, float _y, float _z = 0.0f)
    {
        dde->lineTo(_x, _y, _z);
    }

    ///
    void zbgfx_EncoderClose(DebugDrawEncoder *dde)
    {
        dde->close();
    }

    ///
    void zbgfx_EncoderDrawAABB(DebugDrawEncoder *dde, float min[3], float max[3])
    {
        dde->draw(bx::Aabb{.min = *(bx::Vec3 *)(min), .max = *(bx::Vec3 *)(max)});
    }

    ///
    void zbgfx_EncoderDrawCylinder(DebugDrawEncoder *dde, float pos[3], float end[3], float radius)
    {
        dde->draw(bx::Cylinder{.pos = *(bx::Vec3 *)(pos), .end = *(bx::Vec3 *)(end), .radius = radius});
    }

    ///
    void zbgfx_EncoderDrawCapsule(DebugDrawEncoder *dde, float pos[3], float end[3], float radius)
    {
        dde->draw(bx::Capsule{.pos = *(bx::Vec3 *)(pos), .end = *(bx::Vec3 *)(end), .radius = radius});
    }

    ///
    void zbgfx_EncoderDrawDisk(DebugDrawEncoder *dde, float center[3], float normal[3], float radius)
    {
        dde->draw(bx::Disk{.center = *(bx::Vec3 *)(center), .normal = *(bx::Vec3 *)(normal), .radius = radius});
    }

    ///
    void zbgfx_EncoderDrawObb(DebugDrawEncoder *dde, float _obb[16])
    {
        bx::Obb obb;
        bx::memCopy(obb.mtx, _obb, 16 * sizeof(float));
        dde->draw(obb);
    }

    ///
    void zbgfx_EncoderDrawSphere(DebugDrawEncoder *dde, float center[3], float radius)
    {
        dde->draw(bx::Sphere{.center = *(bx::Vec3 *)(center), .radius = radius});
    }

    ///
    void zbgfx_EncoderDrawTriangle(DebugDrawEncoder *dde, float v0[3], float v1[3], float v2[3])
    {
        dde->draw(bx::Triangle{.v0 = *(bx::Vec3 *)(v0), .v1 = *(bx::Vec3 *)(v1), .v2 = *(bx::Vec3 *)(v2)});
    }

    ///
    void zbgfx_EncoderDrawCone(DebugDrawEncoder *dde, float pos[3], float end[3], float radius)
    {
        dde->draw(bx::Cone{.pos = *(bx::Vec3 *)(pos), .end = *(bx::Vec3 *)(end), .radius = radius});
    }

    ///
    void zbgfx_EncoderDrawGeometry(DebugDrawEncoder *dde, GeometryHandle _handle)
    {
        dde->draw(_handle);
    }

    ///
    void zbgfx_EncoderDrawLineList(DebugDrawEncoder *dde, uint32_t _numVertices, const DdVertex *_vertices, uint32_t _numIndices = 0, const uint16_t *_indices = NULL)
    {
        dde->drawLineList(_numVertices, _vertices, _numIndices, _indices);
    }

    ///
    void zbgfx_EncoderDrawTriList(DebugDrawEncoder *dde, uint32_t _numVertices, const DdVertex *_vertices, uint32_t _numIndices = 0, const uint16_t *_indices = NULL)
    {
        dde->drawTriList(_numVertices, _vertices, _numIndices, _indices);
    }

    ///
    void zbgfx_EncoderDrawFrustum(DebugDrawEncoder *dde, const void *_viewProj)
    {
        dde->drawFrustum(_viewProj);
    }

    ///
    void zbgfx_EncoderDrawArc(DebugDrawEncoder *dde, Axis::Enum _axis, float _x, float _y, float _z, float _radius, float _degrees)
    {
        dde->drawArc(_axis, _x, _y, _z, _radius, _degrees);
    }

    ///
    void zbgfx_EncoderDrawCircle(DebugDrawEncoder *dde, float _normal[3], float _center[3], float _radius, float _weight = 0.0f)
    {
        dde->drawCircle(*(bx::Vec3 *)(_normal), *(bx::Vec3 *)(_center), _radius, _weight);
    }

    ///
    void zbgfx_EncoderDrawCircleAxis(DebugDrawEncoder *dde, Axis::Enum _axis, float _x, float _y, float _z, float _radius, float _weight = 0.0f)
    {
        dde->drawCircle(_axis, _x, _y, _z, _radius, _weight);
    }

    ///
    void zbgfx_EncoderDrawQuad(DebugDrawEncoder *dde, float _normal[3], float _center[3], float _size)
    {
        dde->drawQuad(*(bx::Vec3 *)(_normal), *(bx::Vec3 *)(_center), _size);
    }

    ///
    void zbgfx_EncoderDrawQuadSprite(DebugDrawEncoder *dde, SpriteHandle _handle, float _normal[3], float _center[3], float _size)
    {
        dde->drawQuad(_handle, *(bx::Vec3 *)(_normal), *(bx::Vec3 *)(_center), _size);
    }

    ///
    void zbgfx_EncoderDrawQuadTexture(DebugDrawEncoder *dde, bgfx::TextureHandle _handle, float _normal[3], float _center[3], float _size)
    {
        dde->drawQuad(_handle, *(bx::Vec3 *)(_normal), *(bx::Vec3 *)(_center), _size);
    }

    ///
    void zbgfx_EncoderDrawAxis(DebugDrawEncoder *dde, float _x, float _y, float _z, float _len = 1.0f, Axis::Enum _highlight = Axis::Count, float _thickness = 0.0f)
    {
        dde->drawAxis(_x, _y, _z, _len, _highlight, _thickness);
    }

    ///
    void zbgfx_EncoderDrawGrid(DebugDrawEncoder *dde, float _normal[3], float _center[3], uint32_t _size = 20, float _step = 1.0f)
    {
        dde->drawGrid(*(bx::Vec3 *)(_normal), *(bx::Vec3 *)(_center), _size, _step);
    }

    ///
    void zbgfx_EncoderDrawGridAxis(DebugDrawEncoder *dde, Axis::Enum _axis, float _center[3], uint32_t _size = 20, float _step = 1.0f)
    {
        dde->drawGrid(_axis, *(bx::Vec3 *)(_center), _size, _step);
    }

    ///
    void zbgfx_EncoderDrawOrb(DebugDrawEncoder *dde, float _x, float _y, float _z, float _radius, Axis::Enum _highlight = Axis::Count)
    {
        dde->drawOrb(_x, _y, _z, _radius, _highlight);
    }
}
