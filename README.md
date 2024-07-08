# ZBgfx

[![GitHub Actions](https://github.com/cyberegoorg/zbgfx/actions/workflows/test.yaml/badge.svg)](https://github.com/cyberegoorg/zbgfx/actions/workflows/test.yaml)

When [zig](https://github.com/ziglang/zig) meets [bgfx](https://github.com/bkaradzic/bgfx).

## Features

- [x] Zig api.
- [x] Compile as standard zig library.
- [x] `shaderc` as build artifact.
- [x] Shader compile in `build.zig` to `*.bin.h`.
- [x] Shader compile in `build.zig` and embed as zig module. (this is zig equivalent of `*.bin.h`)
- [ ] Shader compile from runtime via `shaderc` as child process.
- [x] Experimental shader compile from runtime via embeded `shaderc`.
- [x] Binding for [DebugDraw API](https://github.com/bkaradzic/bgfx/tree/master/examples/common/debugdraw)
- [x] `imgui` render backend. Use build option `imgui_include` to enable. ex. for
  zgui: `.imgui_include = zgui.path("libs").getPath(b),`

> [!IMPORTANT]  
> This is only zig binding. For BGFX stuff goto [bgfx](https://github.com/bkaradzic/bgfx).

> [!WARNING]
> - `shaderc` need some time to compile.

> [!NOTE]
> - If you build shaders/app and see something like `run shaderc (shader.bin.h) stderr`.
    This is not "true" error (build success), but only in debug build shader print some stuff to stderr and zig
    build catch it.

## License

Folders `libs`, `shaders` is copy&paste from [bgfx](https://github.com/bkaradzic/bgfx) for more sell-contained
experience and is licensed by [LICENSEE](https://github.com/bkaradzic/bgfx/blob/master/LICENSE)

Zig binding is licensed by [WTFPL](LICENSE)

## Zig version

Minimal is `0.13.0`. But you know try your version and believe.

## Bgfx version

- [BX](https://github.com/bkaradzic/bx/commit/e7ede513dc8b90386960587e348c73b241f7735d)
- [BImg](https://github.com/bkaradzic/bimg/commit/2afa64c14c1e3dd5d28412ee03bee0dfe7242f03)
- [BGFX](https://github.com/bkaradzic/bgfx/commit/74e7edccdc340a56e862c1234626dbb276e88553)

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
| `multithread`   | `true`  | Compile with `BGFX_CONFIG_MULTITHREADED`             |
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
