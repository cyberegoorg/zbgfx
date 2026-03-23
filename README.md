# ZBgfx

[![GitHub Actions](https://github.com/cyberegoorg/zbgfx/actions/workflows/test.yaml/badge.svg)](https://github.com/cyberegoorg/zbgfx/actions/workflows/test.yaml)

When [zig](https://codeberg.org/ziglang/zig) meets [bgfx](https://github.com/bkaradzic/bgfx).

## Features

- [x] Zig api.
- [x] Compile as standard zig library.
- [x] `shaderc` as build artifact.
- [x] Shader compile from runtime via `shaderc` as child process.
- [x] Shader compile in `build.zig` and embed as zig module.
- [x] Binding for [DebugDraw API](https://github.com/bkaradzic/bgfx/tree/master/examples/common/debugdraw)
- [x] `imgui` render backend. Use build option `imgui_include` to enable. ex. for
  zgui: `.imgui_include = zgui.path("libs").getPath(b),`
- [ ] Zig based allocator.

> [!IMPORTANT]
>
> - This is only zig binding. For BGFX stuff goto [bgfx](https://github.com/bkaradzic/bgfx).
> - Github repository is only mirror. Development continues [here](https://codeberg.org/cyberegoorg/zbgfx)

> [!WARNING]
>
> - `shaderc` need some time to compile.

## License

Folders `libs`, `shaders` is copy&paste from [bgfx](https://github.com/bkaradzic/bgfx) for more sell-contained
experience and is licensed by [LICENSEE](https://github.com/bkaradzic/bgfx/blob/master/LICENSE)

Zig binding is licensed by [WTFPL](LICENSE)

## Zig version

Minimal is `0.15.1`. But you know try your version and believe.

## Bgfx version

- [BX](https://github.com/bkaradzic/bx/compare/cac72f6cfa0893393ea12692ebfacb4495f8c826...master)
- [BImg](https://github.com/bkaradzic/bimg/compare/9114b47f532ce59cd0c6c9f8932df2c48888d4c1...master)
- [BGFX](https://github.com/bkaradzic/bgfx/compare/a7016487e5970c5299bb837f1af42dcb24909a67...master)

## Getting started

Copy `zbgfx` to a subdirectory of your project and then add the following to your `build.zig.zon` .dependencies:

```zig
    .zbgfx = .{ .path = "path/to/zbgfx" },
```

or use `zig fetch --save ...` way.

Then in your `build.zig` add:

```zig
pub fn build(b: *std.Build) void {
    const exe = b.addExecutable(.{ ... });

    const zbgfx = b.dependency("zbgfx", .{});
    exe.root_module.addImport("zbgfx", zbgfx.module("zbgfx"));
    exe.linkLibrary(zbgfx.artifact("bgfx"));

    // This install shaderc to install dir
    // For shader build in build =D check examples
    // b.installArtifact(zbgfx.artifact("shaderc"));
}
```

## Usage

See examples for binding usage and [bgfx](https://github.com/bkaradzic/bgfx) for bgfx stuff.

## Build options

| Build option    | Default | Description                                          |
|-----------------|---------|------------------------------------------------------|
| `imgui_include` | `null`  | Path to ImGui includes (need for imgui bgfx backend) |
| `multithread`   | `true`  | Compile with `BGFX_CONFIG_MULTITHREADED`             |
| `with_shaderc`  | `true`  | Compile with `shaderc`                               |

## Examples

Run this for build all examples:

```sh
cd examples
zig build
```

### [Minimal GLFW](examples/minimal-glfw/)

Minimal setup with GLFW for window and input.

```sh
examples/zig-out/bin/minimal-glfw
```

| Key | Description  |
|-----|--------------|
| `v` | Vsync on/off |
| `d` | Debug on/off |

### [Shader embed](examples/shader-embed/)

Basic usage of shaders compiled in build and embed to zig module.

```sh
examples/zig-out/bin/shader-embed
```

| Key | Description  |
|-----|--------------|
| `v` | Vsync on/off |
| `d` | Debug on/off |

### [Shader runtime](examples/shader-runtime/)

Basic usage of shader compile in runtime.
Try edit shaders in `zig-out/bin/shaders` and hit `r` to recompile.

```sh
examples/zig-out/bin/shader-runtime
```

| Key | Description                 |
|-----|-----------------------------|
| `v` | Vsync on/off                |
| `d` | Debug on/off                |
| `r` | Recompile shaders form file |

### [ZGui](examples/zgui/)

Minimal setup for zgui/ImGui.

```sh
examples/zig-out/bin/zgui
```

| Key | Description  |
|-----|--------------|
| `v` | Vsync on/off |
| `d` | Debug on/off |

### [debugdraw](examples/debugdraw/)

DebugDraw api usage example.

```sh
examples/zig-out/bin/debugdraw
```

| Key | Description  |
|-----|--------------|
| `v` | Vsync on/off |
| `d` | Debug on/off |
