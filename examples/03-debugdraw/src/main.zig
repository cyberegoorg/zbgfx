const std = @import("std");
const builtin = @import("builtin");

const math = std.math;
const zglfw = @import("zglfw");
const zm = @import("zmath");

const zbgfx = @import("zbgfx");
const bgfx = zbgfx.bgfx;
const debugdraw = zbgfx.debugdraw;

const WIDTH = 1280;
const HEIGHT = 720;

var bgfx_clbs = zbgfx.callbacks.CCallbackInterfaceT{
    .vtable = &zbgfx.callbacks.DefaultZigCallbackVTable.toVtbl(),
};
var bgfx_alloc: zbgfx.callbacks.ZigAllocator = undefined;

var debug = true;
var vsync = true;

var last_v = zglfw.Action.release;
var last_d = zglfw.Action.release;
var old_flags = bgfx.ResetFlags_None;
var old_size = [2]i32{ WIDTH, HEIGHT };

pub fn main() anyerror!u8 {
    //
    // Init zglfw
    //
    try zglfw.init();
    defer zglfw.terminate();

    //
    // Create window
    //
    zglfw.windowHint(.client_api, .no_api);
    const window = try zglfw.Window.create(WIDTH, HEIGHT, "ZBgfx - debugdraw", null);
    defer window.destroy();
    window.setSizeLimits(400, 400, -1, -1);

    //
    // Init bgfx init params
    //
    var bgfx_init: bgfx.Init = undefined;
    bgfx.initCtor(&bgfx_init);

    // This force renderer type.
    // bgfx_init.type = .Vulkan

    const framebufferSize = window.getFramebufferSize();
    bgfx_init.resolution.width = @intCast(framebufferSize[0]);
    bgfx_init.resolution.height = @intCast(framebufferSize[1]);
    bgfx_init.platformData.ndt = null;
    bgfx_init.debug = true;

    // TODO: read note in zbgfx.callbacks.ZigAllocator
    //bgfx_alloc = zbgfx.callbacks.ZigAllocator.init(&_allocator);
    //bgfx_init.allocator = &bgfx_alloc;

    bgfx_init.callback = &bgfx_clbs;

    //
    // Set native handles
    //
    switch (builtin.target.os.tag) {
        .linux => {
            bgfx_init.platformData.type = bgfx.NativeWindowHandleType.Default;
            bgfx_init.platformData.nwh = @ptrFromInt(zglfw.getX11Window(window));
            bgfx_init.platformData.ndt = zglfw.getX11Display();
        },
        .windows => {
            bgfx_init.platformData.nwh = zglfw.getWin32Window(window);
        },
        else => |v| if (v.isDarwin()) {
            bgfx_init.platformData.nwh = zglfw.getCocoaWindow(window);
        } else undefined,
    }

    //
    // Init bgfx
    //

    // Do not create render thread
    _ = bgfx.renderFrame(-1);

    if (!bgfx.init(&bgfx_init)) std.process.exit(1);
    defer bgfx.shutdown();

    var reset_flags = bgfx.ResetFlags_None;
    if (vsync) {
        reset_flags |= bgfx.ResetFlags_Vsync;
    }

    //
    // Reset and clear
    //
    bgfx.reset(@intCast(framebufferSize[0]), @intCast(framebufferSize[1]), reset_flags, bgfx_init.resolution.formatColor);

    // Set view 0 clear state.
    bgfx.setViewClear(0, bgfx.ClearFlags_Color | bgfx.ClearFlags_Depth, 0x303030ff, 1.0, 0);

    //
    // Create view and proj matrices
    //
    const viewMtx = zm.lookAtRh(zm.f32x4(0.0, 2.0, 12.0, 1.0), zm.f32x4(0.0, 2.0, 1.0, 1.0), zm.f32x4(0.0, 1.0, 0.0, 0.0));
    var projMtx: zm.Mat = undefined;

    // init debugdraw
    debugdraw.init();
    defer debugdraw.deinit();

    const dde = debugdraw.Encoder.create();
    defer debugdraw.Encoder.destroy(dde);

    const bunny = debugdraw.createGeometry(bunnyVertices.len, &bunnyVertices, bunnyTriList.len, @ptrCast(&bunnyTriList), false);
    defer debugdraw.destroyGeometry(bunny);

    var data: [32 * 32 * 4]u32 = undefined;
    imageCheckerboard(&data, 32, 32, 4, 0xff808080, 0xffc0c0c0);
    const sprite = debugdraw.createSprite(32, 32, std.mem.asBytes(&data));

    //
    // Main loop
    //
    const start_time: i64 = std.time.milliTimestamp();
    _ = start_time; // autofix
    while (!window.shouldClose() and window.getKey(.escape) != .press) {
        //
        // Poll events
        //
        zglfw.pollEvents();

        //
        // Check keyboard
        //
        if (last_d != .press and window.getKey(.d) == .press) {
            debug = !debug;
        }
        if (last_v != .press and window.getKey(.v) == .press) {
            vsync = !vsync;
        }
        last_v = window.getKey(.v);
        last_d = window.getKey(.d);

        //
        // New flags?
        //
        reset_flags = bgfx.ResetFlags_None;
        if (vsync) {
            reset_flags |= bgfx.ResetFlags_Vsync;
        }

        //
        // Show debug
        //
        if (debug) {
            bgfx.setDebug(bgfx.DebugFlags_Stats);
        } else {
            bgfx.setDebug(bgfx.DebugFlags_None);
        }

        //
        // I resolution or flags is changed set new matrix and reset.
        //
        const size = window.getFramebufferSize();
        if (old_flags != reset_flags or old_size[0] != size[0] or old_size[1] != size[1]) {
            const aspect_ratio = @as(f32, @floatFromInt(size[0])) / @as(f32, @floatFromInt(size[1]));
            projMtx = zm.perspectiveFovRhGl(
                0.25 * math.pi,
                aspect_ratio,
                0.1,
                1000.0,
            );

            bgfx.reset(
                @intCast(size[0]),
                @intCast(size[1]),
                reset_flags,
                bgfx_init.resolution.formatColor,
            );
            old_size = size;
            old_flags = reset_flags;
        }

        //
        //  Preapare view
        //
        bgfx.setViewTransform(0, &zm.matToArr(viewMtx), &zm.matToArr(projMtx));
        bgfx.setViewRect(0, 0, 0, @intCast(size[0]), @intCast(size[1]));
        bgfx.touch(0);
        bgfx.dbgTextClear(0, false);

        // DebugDraw
        {
            dde.begin(0, true, null);
            defer dde.end();

            dde.drawAxis(.{ 0, 0, 0 }, 1.0, .Count, 0.0);

            // Bunny
            dde.push();
            {
                defer dde.pop();

                const s = zm.scaling(0.03, 0.03, 0.03);
                const t = zm.translation(-3, 0, 0);

                const st = zm.mul(s, t);
                dde.setTransform(&zm.matToArr(st));
                dde.drawGeometry(bunny);
                dde.setTransform(null);
            }

            // Sprite
            dde.push();
            {
                defer dde.pop();

                dde.drawQuadSprite(
                    sprite,
                    .{ 0.0, 0.0, 1.0 },
                    .{ -2.0, 0.0, -10.0 },
                    2.0,
                );
            }

            // Sphere
            dde.push();
            {
                defer dde.pop();

                dde.drawSphere(.{ 3, 0, 0 }, 0.5);
            }

            // Grid
            dde.push();
            {
                defer dde.pop();
                dde.drawGridAxis(.Y, .{ 0, -2, 0 }, 128, 1);
            }
        }

        // Render Frame
        _ = bgfx.frame(false);
    }

    return 0;
}

fn imageCheckerboard(_dst: []u32, _width: u32, _height: u32, _step: u32, _0: u32, _1: u32) void {
    var idx: u32 = 0;

    for (0.._height) |yy| {
        for (0.._width) |xx| {
            const abgr: u32 = if (0 != (((xx / _step) & 1) ^ ((yy / _step) & 1))) _1 else _0;
            _dst[idx] = abgr;

            idx += 1;
        }
    }
}

const bunnyVertices = [_]debugdraw.Vertex{
    .{ .x = 25.0883, .y = -44.2788, .z = 31.0055 },
    .{ .x = 0.945623, .y = 53.5504, .z = -24.6146 },
    .{ .x = -0.94455, .y = -14.3443, .z = -16.8223 },
    .{ .x = -20.1103, .y = -48.6664, .z = 12.6763 },
    .{ .x = -1.60652, .y = -26.3165, .z = -24.5424 },
    .{ .x = -30.6284, .y = -53.6299, .z = 14.7666 },
    .{ .x = 1.69145, .y = -43.8075, .z = -15.2065 },
    .{ .x = -20.5139, .y = 21.0521, .z = -5.40868 },
    .{ .x = -13.9518, .y = 53.6299, .z = -39.1193 },
    .{ .x = -21.7912, .y = 48.7801, .z = -42.0995 },
    .{ .x = -26.8408, .y = 23.6537, .z = -17.7324 },
    .{ .x = -23.1196, .y = 33.9692, .z = 4.91483 },
    .{ .x = -12.3236, .y = -41.6303, .z = 31.8324 },
    .{ .x = 27.6427, .y = -5.05034, .z = -11.3201 },
    .{ .x = 32.2565, .y = 1.30521, .z = 30.2671 },
    .{ .x = 47.2723, .y = -27.0974, .z = 11.1774 },
    .{ .x = 33.598, .y = 10.5888, .z = 7.95916 },
    .{ .x = -13.2898, .y = 12.6234, .z = 5.55953 },
    .{ .x = -32.7364, .y = 19.0648, .z = -10.5736 },
    .{ .x = -32.7536, .y = 31.4158, .z = -1.40712 },
    .{ .x = -25.3672, .y = 30.2874, .z = -12.4682 },
    .{ .x = 32.921, .y = -36.8408, .z = -12.0254 },
    .{ .x = -37.7251, .y = -33.8989, .z = 0.378443 },
    .{ .x = -35.6341, .y = -0.246891, .z = -9.25165 },
    .{ .x = -16.7041, .y = -50.0254, .z = -15.6177 },
    .{ .x = 24.6604, .y = -53.5319, .z = -11.1059 },
    .{ .x = -7.77574, .y = -53.5719, .z = -16.6655 },
    .{ .x = 20.6241, .y = 13.3489, .z = 0.376349 },
    .{ .x = -44.2889, .y = 29.5222, .z = 18.7918 },
    .{ .x = 18.5805, .y = 16.3651, .z = 12.6351 },
    .{ .x = -23.7853, .y = 31.7598, .z = -6.54093 },
    .{ .x = 24.7518, .y = -53.5075, .z = 2.14984 },
    .{ .x = -45.7912, .y = -17.6301, .z = 21.1198 },
    .{ .x = 51.8403, .y = -33.1847, .z = 24.3337 },
    .{ .x = -47.5343, .y = -4.32792, .z = 4.06232 },
    .{ .x = -50.6832, .y = -12.442, .z = 11.0994 },
    .{ .x = -49.5132, .y = 19.2782, .z = 3.17559 },
    .{ .x = -39.4881, .y = 29.0208, .z = -6.70431 },
    .{ .x = -52.7286, .y = 1.23232, .z = 9.74872 },
    .{ .x = 26.505, .y = -16.1297, .z = -17.0487 },
    .{ .x = -25.367, .y = 20.0473, .z = -8.44282 },
    .{ .x = -24.5797, .y = -10.3143, .z = -18.3154 },
    .{ .x = -28.6707, .y = 6.12074, .z = 27.8025 },
    .{ .x = -16.9868, .y = 22.6819, .z = 1.37408 },
    .{ .x = -37.2678, .y = 23.9443, .z = -9.4945 },
    .{ .x = -24.8562, .y = 21.3763, .z = 18.8847 },
    .{ .x = -47.1879, .y = 3.8542, .z = -4.74621 },
    .{ .x = 38.0706, .y = -7.33673, .z = -7.6099 },
    .{ .x = -34.8833, .y = -3.57074, .z = 26.4838 },
    .{ .x = 12.3797, .y = 5.46782, .z = 32.9762 },
    .{ .x = -31.5974, .y = -22.956, .z = 30.5827 },
    .{ .x = -6.80953, .y = 48.055, .z = -18.5116 },
    .{ .x = 6.3474, .y = -15.1622, .z = -24.4726 },
    .{ .x = -25.5733, .y = 25.2452, .z = -34.4736 },
    .{ .x = -23.8955, .y = 31.8323, .z = -40.8696 },
    .{ .x = -11.8622, .y = 38.2304, .z = -43.3125 },
    .{ .x = -20.4918, .y = 41.2409, .z = -3.11271 },
    .{ .x = 24.9806, .y = -8.53455, .z = 37.2862 },
    .{ .x = -52.8935, .y = 5.3376, .z = 28.246 },
    .{ .x = 34.106, .y = -41.7941, .z = 30.962 },
    .{ .x = -1.26914, .y = 35.6664, .z = -18.7177 },
    .{ .x = -0.13048, .y = 44.7288, .z = -28.7163 },
    .{ .x = 2.47929, .y = 0.678165, .z = -14.6892 },
    .{ .x = -31.8649, .y = -14.2299, .z = 32.2998 },
    .{ .x = -19.774, .y = 30.8258, .z = 5.77293 },
    .{ .x = 49.8059, .y = -37.125, .z = 4.97284 },
    .{ .x = -28.0581, .y = -26.439, .z = -14.8316 },
    .{ .x = -9.12066, .y = -27.3987, .z = -12.8592 },
    .{ .x = -13.8752, .y = -29.9821, .z = 32.5962 },
    .{ .x = -6.6222, .y = -10.9884, .z = 33.5007 },
    .{ .x = -21.2664, .y = -53.6089, .z = -3.49195 },
    .{ .x = -0.628672, .y = 52.8093, .z = -9.88088 },
    .{ .x = 8.02417, .y = 51.8956, .z = -21.5834 },
    .{ .x = -44.6547, .y = 11.9973, .z = 34.7897 },
    .{ .x = -7.55466, .y = 37.9035, .z = -0.574101 },
    .{ .x = 52.8252, .y = -27.1986, .z = 11.6429 },
    .{ .x = -0.934591, .y = 9.81861, .z = 0.512566 },
    .{ .x = -3.01043, .y = 5.70605, .z = 22.0954 },
    .{ .x = -34.6337, .y = 44.5964, .z = -31.1713 },
    .{ .x = -26.9017, .y = 35.1991, .z = -32.4307 },
    .{ .x = 15.9884, .y = -8.92223, .z = -14.7411 },
    .{ .x = -22.8337, .y = -43.458, .z = 26.7274 },
    .{ .x = -31.9864, .y = -47.0243, .z = 9.36972 },
    .{ .x = -36.9436, .y = 24.1866, .z = 29.2521 },
    .{ .x = -26.5411, .y = 29.6549, .z = 21.2867 },
    .{ .x = 33.7644, .y = -24.1886, .z = -13.8513 },
    .{ .x = -2.44749, .y = -17.0148, .z = 41.6617 },
    .{ .x = -38.364, .y = -13.9823, .z = -12.5705 },
    .{ .x = -10.2972, .y = -51.6584, .z = 38.935 },
    .{ .x = 1.28109, .y = -43.4943, .z = 36.6288 },
    .{ .x = -19.7784, .y = -44.0413, .z = -4.23994 },
    .{ .x = 37.0944, .y = -53.5479, .z = 27.6467 },
    .{ .x = 24.9642, .y = -37.1722, .z = 35.7038 },
    .{ .x = 37.5851, .y = 5.64874, .z = 21.6702 },
    .{ .x = -17.4738, .y = -53.5734, .z = 30.0664 },
    .{ .x = -8.93088, .y = 45.3429, .z = -34.4441 },
    .{ .x = -17.7111, .y = -6.5723, .z = 29.5162 },
    .{ .x = 44.0059, .y = -17.4408, .z = -5.08686 },
    .{ .x = -46.2534, .y = -22.6115, .z = 0.702059 },
    .{ .x = 43.9321, .y = -33.8575, .z = 4.31819 },
    .{ .x = 41.6762, .y = -7.37115, .z = 27.6798 },
    .{ .x = 8.20276, .y = -42.0948, .z = -18.0893 },
    .{ .x = 26.2678, .y = -44.6777, .z = -10.6835 },
    .{ .x = 17.709, .y = 13.1542, .z = 25.1769 },
    .{ .x = -35.9897, .y = 3.92007, .z = 35.8198 },
    .{ .x = -23.9323, .y = -37.3142, .z = -2.39396 },
    .{ .x = 5.19169, .y = 46.8851, .z = -28.7587 },
    .{ .x = -37.3072, .y = -35.0484, .z = 16.9719 },
    .{ .x = 45.0639, .y = -28.5255, .z = 22.3465 },
    .{ .x = -34.4175, .y = 35.5861, .z = -21.7562 },
    .{ .x = 9.32684, .y = -12.6655, .z = 42.189 },
    .{ .x = 1.00938, .y = -31.7694, .z = 43.1914 },
    .{ .x = -45.4666, .y = -3.71104, .z = 19.2248 },
    .{ .x = -28.7999, .y = -50.8481, .z = 31.5232 },
    .{ .x = 35.2212, .y = -45.9047, .z = 0.199736 },
    .{ .x = 40.3, .y = -53.5889, .z = 7.47622 },
    .{ .x = 29.0515, .y = 5.1074, .z = -10.002 },
    .{ .x = 13.4336, .y = 4.84341, .z = -9.72327 },
    .{ .x = 11.0617, .y = -26.245, .z = -24.9471 },
    .{ .x = -35.6056, .y = -51.2531, .z = 0.436527 },
    .{ .x = -10.6863, .y = 34.7374, .z = -36.7452 },
    .{ .x = -51.7652, .y = 27.4957, .z = 7.79363 },
    .{ .x = -50.1898, .y = 18.379, .z = 26.3763 },
    .{ .x = -49.6836, .y = -1.32722, .z = 26.2828 },
    .{ .x = 19.0363, .y = -16.9114, .z = 41.8511 },
    .{ .x = 32.7141, .y = -21.501, .z = 36.0025 },
    .{ .x = 12.5418, .y = -28.4244, .z = 43.3125 },
    .{ .x = -19.5634, .y = 42.6328, .z = -27.0687 },
    .{ .x = -16.1942, .y = 6.55011, .z = 19.4066 },
    .{ .x = 46.9886, .y = -18.8482, .z = 22.1332 },
    .{ .x = 45.9697, .y = -3.76781, .z = 4.10111 },
    .{ .x = -28.2912, .y = 51.3277, .z = -35.1815 },
    .{ .x = -40.2796, .y = -27.7518, .z = 22.8684 },
    .{ .x = -22.7984, .y = -38.9977, .z = 22.158 },
    .{ .x = 54.0614, .y = -35.6096, .z = 12.694 },
    .{ .x = 44.2064, .y = -53.6029, .z = 18.8679 },
    .{ .x = 19.789, .y = -29.517, .z = -19.6094 },
    .{ .x = -34.3769, .y = 34.8566, .z = 9.92517 },
    .{ .x = -23.7518, .y = -45.0319, .z = 8.71282 },
    .{ .x = -12.7978, .y = 3.55087, .z = -13.7108 },
    .{ .x = -54.0614, .y = 8.83831, .z = 8.91353 },
    .{ .x = 16.2986, .y = -53.5717, .z = 34.065 },
    .{ .x = -36.6243, .y = -53.5079, .z = 24.6495 },
    .{ .x = 16.5794, .y = -48.5747, .z = 35.5681 },
    .{ .x = -32.3263, .y = 41.4526, .z = -18.7388 },
    .{ .x = -18.8488, .y = 9.62627, .z = -8.81052 },
    .{ .x = 5.35849, .y = 36.3616, .z = -12.9346 },
    .{ .x = 6.19167, .y = 34.497, .z = -17.965 },
};

const bunnyTriList = [_]u16{
    80,  2,   52,
    0,   143, 92,
    51,  1,   71,
    96,  128, 77,
    67,  2,   41,
    85,  39,  52,
    58,  123, 38,
    99,  21,  114,
    55,  9,   54,
    136, 102, 21,
    3,   133, 81,
    101, 136, 4,
    5,   82,  3,
    6,   90,  24,
    7,   40,  145,
    33,  75,  134,
    55,  8,   9,
    10,  40,  20,
    46,  140, 38,
    74,  64,  11,
    89,  88,  12,
    147, 60,  7,
    47,  116, 13,
    59,  129, 108,
    147, 72,  106,
    33,  108, 75,
    100, 57,  14,
    129, 130, 15,
    32,  35,  112,
    16,  29,  27,
    107, 98,  132,
    130, 116, 47,
    17,  43,  7,
    54,  44,  53,
    46,  34,  23,
    87,  41,  23,
    40,  10,  18,
    8,   131, 9,
    11,  19,  56,
    11,  137, 19,
    19,  20,  30,
    28,  121, 137,
    122, 140, 36,
    15,  130, 97,
    28,  84,  83,
    114, 21,  102,
    87,  98,  22,
    41,  145, 23,
    133, 68,  12,
    90,  70,  24,
    31,  25,  26,
    98,  34,  35,
    16,  27,  116,
    28,  83,  122,
    29,  103, 77,
    40,  30,  20,
    14,  49,  103,
    31,  26,  142,
    78,  9,   131,
    80,  62,  2,
    6,   67,  105,
    32,  48,  63,
    60,  30,  7,
    33,  135, 91,
    116, 130, 16,
    47,  13,  39,
    70,  119, 5,
    24,  26,  6,
    102, 25,  31,
    103, 49,  77,
    16,  130, 93,
    125, 126, 124,
    111, 86,  110,
    4,   52,  2,
    87,  34,  98,
    4,   6,   101,
    29,  76,  27,
    112, 35,  34,
    6,   4,   67,
    72,  1,   106,
    26,  24,  70,
    36,  37,  121,
    81,  113, 142,
    44,  109, 37,
    122, 58,  38,
    96,  48,  128,
    71,  11,  56,
    73,  122, 83,
    52,  39,  80,
    40,  18,  145,
    82,  5,   119,
    10,  20,  120,
    139, 145, 41,
    3,   142, 5,
    76,  117, 27,
    95,  120, 20,
    104, 45,  42,
    128, 43,  17,
    44,  37,  36,
    128, 45,  64,
    143, 111, 126,
    34,  46,  38,
    97,  130, 47,
    142, 91,  115,
    114, 31,  115,
    125, 100, 129,
    48,  96,  63,
    62,  41,  2,
    69,  77,  49,
    133, 50,  68,
    60,  51,  30,
    4,   118, 52,
    53,  55,  54,
    95,  8,   55,
    121, 37,  19,
    65,  75,  99,
    51,  56,  30,
    14,  57,  110,
    58,  122, 73,
    59,  92,  125,
    42,  45,  128,
    49,  14,  110,
    60,  147, 61,
    76,  62,  117,
    69,  49,  86,
    26,  5,   142,
    46,  44,  36,
    63,  50,  132,
    128, 64,  43,
    75,  108, 15,
    134, 75,  65,
    68,  69,  86,
    62,  76,  145,
    142, 141, 91,
    67,  66,  105,
    69,  68,  96,
    119, 70,  90,
    33,  91,  108,
    136, 118, 4,
    56,  51,  71,
    1,   72,  71,
    23,  18,  44,
    104, 123, 73,
    106, 1,   61,
    86,  111, 68,
    83,  45,  104,
    30,  56,  19,
    15,  97,  99,
    71,  74,  11,
    15,  99,  75,
    25,  102, 6,
    12,  94,  81,
    135, 33,  134,
    138, 133, 3,
    76,  29,  77,
    94,  88,  141,
    115, 31,  142,
    36,  121, 122,
    4,   2,   67,
    9,   78,  79,
    137, 121, 19,
    69,  96,  77,
    13,  62,  80,
    8,   127, 131,
    143, 141, 89,
    133, 12,  81,
    82,  119, 138,
    45,  83,  84,
    21,  85,  136,
    126, 110, 124,
    86,  49,  110,
    13,  116, 117,
    22,  66,  87,
    141, 88,  89,
    64,  45,  84,
    79,  78,  109,
    26,  70,  5,
    14,  93,  100,
    68,  50,  63,
    90,  105, 138,
    141, 0,   91,
    105, 90,  6,
    0,   92,  59,
    17,  145, 76,
    29,  93,  103,
    113, 81,  94,
    39,  85,  47,
    132, 35,  32,
    128, 48,  42,
    93,  29,  16,
    145, 18,  23,
    108, 129, 15,
    32,  112, 48,
    66,  41,  87,
    120, 95,  55,
    96,  68,  63,
    85,  99,  97,
    18,  53,  44,
    22,  98,  107,
    98,  35,  132,
    95,  127, 8,
    137, 64,  84,
    18,  10,  53,
    21,  99,  85,
    54,  79,  44,
    100, 93,  130,
    142, 3,   81,
    102, 101, 6,
    93,  14,  103,
    42,  48,  104,
    87,  23,  34,
    66,  22,  105,
    106, 61,  147,
    72,  74,  71,
    109, 144, 37,
    115, 65,  99,
    107, 132, 133,
    94,  12,  88,
    108, 91,  59,
    43,  64,  74,
    109, 78,  144,
    43,  147, 7,
    91,  135, 115,
    111, 110, 126,
    38,  112, 34,
    142, 113, 94,
    54,  9,   79,
    120, 53,  10,
    138, 3,   82,
    114, 102, 31,
    134, 65,  115,
    105, 22,  107,
    125, 129, 59,
    37,  144, 19,
    17,  76,  77,
    89,  12,  111,
    41,  66,  67,
    13,  117, 62,
    116, 27,  117,
    136, 52,  118,
    51,  60,  61,
    138, 119, 90,
    53,  120, 55,
    68,  111, 12,
    122, 121, 28,
    123, 58,  73,
    110, 57,  124,
    47,  85,  97,
    44,  79,  109,
    126, 125, 92,
    43,  74,  146,
    20,  19,  127,
    128, 17,  77,
    72,  146, 74,
    115, 99,  114,
    140, 122, 38,
    133, 105, 107,
    129, 100, 130,
    131, 144, 78,
    95,  20,  127,
    123, 48,  112,
    102, 136, 101,
    89,  111, 143,
    28,  137, 84,
    133, 132, 50,
    125, 57,  100,
    38,  123, 112,
    124, 57,  125,
    135, 134, 115,
    23,  44,  46,
    136, 85,  52,
    41,  62,  139,
    137, 11,  64,
    104, 48,  123,
    133, 138, 105,
    145, 139, 62,
    25,  6,   26,
    7,   30,  40,
    46,  36,  140,
    141, 143, 0,
    132, 32,  63,
    83,  104, 73,
    19,  144, 127,
    142, 94,  141,
    39,  13,  80,
    92,  143, 126,
    127, 144, 131,
    51,  61,  1,
    91,  0,   59,
    17,  7,   145,
    43,  146, 147,
    146, 72,  147,
};
