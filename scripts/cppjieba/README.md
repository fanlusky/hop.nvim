# Prebuilt cppjieba for Windows

`:HopWordJieba` needs the native `cppjieba` Lua module
([Freed-Wu/jieba.nvim](https://github.com/Freed-Wu/jieba.nvim), GPL-3.0) and its
dictionaries ([yanyiwu/cppjieba](https://github.com/yanyiwu/cppjieba), MIT).
Building it on Windows is fiddly, so a prebuilt archive is attached to the
`cppjieba-win-x64-*` releases of this repository and downloaded by
`lua/hop/jieba_install.lua` (automatically from lazy.nvim's `build.lua`, or with
`:HopJiebaInstall`).

The archive contains:

- `cppjieba.dll` – built against Neovim's `lua51.dll` (LuaJIT) with a static
  MSVC runtime, so it only depends on `lua51.dll` and `KERNEL32.dll`;
- `dict/` – the dictionaries needed for word segmentation;
- `licenses/` and `source/` – upstream licenses and the patched build sources.

## Patches

Upstream `cppjieba` 5.6.3-1 needs these fixes (see the `.patch` files here):

- `cppjieba.patch`
  - the constructor was declared as `c_call "Jieba *>1"`, which returned an
    extra, uninitialized "owned" pointer; freeing it on garbage collection
    crashed Neovim;
  - `cut()` leaked one `malloc` per word;
  - link the MSVC runtime statically.
- `native_objects-gen_lua.patch` (in `luanativeobjects`): the generated C does
  `typedef int bool;`, which clashes with `<stdbool.h>` on MSVC.

## Rebuilding

Requirements: Visual Studio (C++), xmake, a Lua 5.1 interpreter with headers and
luarocks. Use ASCII-only paths for everything (luarocks breaks on non-ASCII user
profile paths), e.g. `C:\lua51` and the tree `C:\nvim-rocks`.

1. Create an import library for Neovim's LuaJIT so the module binds to it:

   ```powershell
   $dll = "<neovim>\bin\lua51.dll"
   $names = dumpbin /exports $dll | % { if ($_ -match '^\s+\d+\s+[0-9A-F]+\s+[0-9A-F]{8}\s+(\S+)') { $Matches[1] } }
   "LIBRARY lua51.dll`nEXPORTS`n" + ($names -join "`n") | Set-Content -Encoding ascii C:\lua51\lua51.def
   lib /def:C:\lua51\lua51.def /out:C:\lua51\lua51.lib /machine:x64
   ```

2. Install `luanativeobjects`, apply `native_objects-gen_lua.patch` to
   `<tree>\share\lua\5.1`, and make `native_objects` findable by xmake (xmake
   only looks for `native_objects.exe`, so wrap the generated `.bat` with a
   shim).
3. `luarocks unpack cppjieba 5.6.3-1`, apply `cppjieba.patch` inside
   `jieba.nvim-5.6.3`, then run `luarocks make ..\cppjieba-5.6.3-1.rockspec`.
4. Package `lib\lua\5.1\cppjieba.dll`, the `dict` files listed in
   `lua/hop/jieba_install.lua`, the licenses and the patched sources into
   `cppjieba-win-x64.zip`, with those files at the archive root.
