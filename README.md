# ZBgfx

[![GitHub Actions](https://github.com/cyberegoorg/zbgfx/actions/workflows/test.yaml/badge.svg)](https://github.com/cyberegoorg/zbgfx/actions/workflows/test.yaml)

When [zig](https://github.com/ziglang/zig) meets [bgfx](https://github.com/bkaradzic/bgfx).

## Features

- [x] Zig api.
- [x] Compile as standard zig library.
- [x] `shaderc` as build artifact.
- [x] Shader compile in `build.zig` to `*.bin.h`.
- [x] Shader compile in `build.zig` and embed as zig module. (this is zig equivalent of `*.bin.h`)
- [x] Shader compile from code (in memory solution, no tmp files).
- [x] Binding for [DebugDraw API](https://github.com/bkaradzic/bgfx/tree/master/examples/common/debugdraw)
- [x] `imgui` render backend. Use build option `imgui_include` to enable. ex. for
  zgui: `.imgui_include = zgui.path("libs").getPath(b),`

> [!IMPORTANT]  
> This is only zig binding. For BGFX stuff goto [bgfx](https://github.com/bkaradzic/bgfx).

> [!WARNING]
> - Shader compile/shaderc api is first draft and need cleanup.
> - Binding for DebugDraw is first draft and need cleanup.
> - `shaderc` need some time to compile.

> [!CAUTION]
> - On retina/hidpi display imgui rendering is broken but is probably simple to fix. (WIP)
> - If you build shaders/app and see something like `run shaderc (shader.bin.h) stderr`.
    Remember is not "true" error but only in debug build shader print some stuff to stderr and zig build catch it.

## Zig version

Minimal is `0.12.0`. But you know.. try your version and believe.
I am open to make some backward compatibility changes but not older version then `0.12.0`.

## Getting started

Copy `zbgfx` to a subdirectory of your project and add the following to your `build.zig.zon` .dependencies:

```zig
    .zbgfx = .{ .path = "path/to/zbgfx" },
```

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
| `multithread`   | `true`  | Compile with BGFX_CONFIG_MULTITHREAD                 |
| `with_shaderc`  | `true`  | Compile with `shaderc`                               |

## Examples

Examples use [zig-gamedev](https://github.com/zig-gamedev/zig-gamedev) as submodule.

Run this to fetch `zig-gamedev`:

```bash
git submodule update --init --depth=1
```

And this for build all examples:

```sh
cd examples
zig build
```

### [00-Minimal](examples/00-minimal/)

Minimal setup with GLFW for window and input.

```sh
examples/zig-out/bin/00-minimal
```

| Key | Description  |
|-----|--------------|
| `v` | Vsync on/off |
| `d` | Debug on/off |

### [01-ZGui](examples/01-zgui/)

Minimal setup for zgui/ImGui.

```sh
examples/zig-out/bin/01-zgui
```

| Key | Description  |
|-----|--------------|
| `v` | Vsync on/off |
| `d` | Debug on/off |

### [02-Runtime shaderc](examples/02-runtime-shaderc/)

Basic usage of shader compile in runtime.
Try edit shaders in `zig-out/bin/shaders` and hit `r` to recompile.

```sh
examples/zig-out/bin/02-runtime-shaderc
```

| Key | Description                 |
|-----|-----------------------------|
| `v` | Vsync on/off                |
| `d` | Debug on/off                |
| `r` | Recompile shaders form file |

### [03-debugdraw](examples/03-debugdraw/)

DebugDraw api usage example.

```sh
examples/zig-out/bin/03-debugdraw
```

| Key | Description  |
|-----|--------------|
| `v` | Vsync on/off |
| `d` | Debug on/off |

## License

Folders `libs`, `shaders` is copy&paste from [bgfx](https://github.com/bkaradzic/bgfx) for more sell-contained
experience and is licensed by [LICENSEE](https://github.com/bkaradzic/bgfx/blob/master/LICENSE)
Zig binding is licensed by [WTFPL](LICENSE)
