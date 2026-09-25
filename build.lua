-- lazy.nvim runs this file after installing or updating the plugin: fetch the
-- prebuilt cppjieba module used by HopWordJieba (64-bit Windows only).
local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h')
local install = dofile(root .. '/lua/hop/jieba_install.lua')

if install.supported() then
  local ok, err = install.install()
  if not ok then
    error('hop.nvim: could not install cppjieba: ' .. err)
  end
end
