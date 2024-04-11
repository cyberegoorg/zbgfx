# ZBgfx

[![GitHub Actions](https://github.com/cyberegoorg/zbgfx/actions/workflows/test.yaml/badge.svg)](https://github.com/cyberegoorg/zbgfx/actions/workflows/test.yaml)

When [zig](https://github.com/ziglang/zig) meets [bgfx](https://github.com/bkaradzic/bgfx).

REMEMBER: This is only zig bindig for BGFX. For BGFX stuff goto [bgfx](https://github.com/bkaradzic/bgfx).

## Features

- [x] Zig api.
- [x] Compile as standard zig library.
- [x] `imgui` render backend. Use build option `imgui_include` to enable. ex. for zgui: `.imgui_include = zgui.path("libs").getPath(b),`
- [x] `shaderc` as build artifact.
- [x] Shader compile in `build.zig` to `*.bin.h`.
- [x] Shader compile in `build.zig` and embed as zig module. (this is zig equivalent of `*.bin.h`)
- [ ] WIP: Shader compile from code (in memory solution, no tmp files).
- [ ] WIP: [DebugDraw API](https://github.com/bkaradzic/bgfx/tree/master/examples/common/debugdraw)

## Warnings

- Shader compile api for building shaders in `build.zig` is first draft and need cleanup.

## Know problems

- On retina/hidpi display imgui rendering is broken but is probably simple to fix. (WIP)
- If you build shaders/app and see something like `run shaderc (shader.bin.h) stderr`.
  Remember is not "true" error but only in debug build shaderc print some stuff to stderr and zig build catch it.

## Zig version

Minimal is `0.12.0`. But you know.. try your version and belive.
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

## Examples

### [00-Minimal](examples/00-minimal/)

```sh
cd examples/minimal
zig build
```

```sh
zig-out/bin/minimal
```

### [01-Minimal-ZGui](examples/01-minimal-zgui/)

```sh
cd examples/minimal
zig build
```

```sh
zig-out/bin/minimal-zgui
```
