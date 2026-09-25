-- Download and locate the prebuilt cppjieba module used by HopWordJieba.
--
-- On 64-bit Windows the native module and its dictionaries are fetched from a
-- release of this repository (see scripts/cppjieba/README.md), so no local
-- build toolchain is needed.  Other platforms keep using a luarocks install.
local M = {}

M.tag = 'cppjieba-win-x64-v1'
M.url = 'https://github.com/fanlusky/hop.nvim/releases/download/' .. M.tag .. '/cppjieba-win-x64.zip'

local dict_files = {
  dict = 'jieba.dict.utf8',
  model = 'hmm_model.utf8',
  idf = 'idf.utf8',
  stop_word = 'stop_words.utf8',
}

---@return boolean
function M.supported()
  return vim.fn.has('win64') == 1
end

---@return string
function M.dir()
  return vim.fn.stdpath('data') .. '/hop.nvim/' .. M.tag
end

---@return boolean
function M.is_installed()
  local dir = M.dir()
  if not vim.uv.fs_stat(dir .. '/cppjieba.dll') then
    return false
  end
  for _, file in pairs(dict_files) do
    if not vim.uv.fs_stat(dir .. '/dict/' .. file) then
      return false
    end
  end
  return true
end

-- Dictionary paths of the prebuilt package, in the shape of `jieba_paths`.
---@return table|nil
function M.paths()
  if not M.is_installed() then
    return nil
  end
  local dict = M.dir() .. '/dict/'
  local paths = { user_dict = 'nul' }
  for key, file in pairs(dict_files) do
    paths[key] = dict .. file
  end
  return paths
end

-- Make `require('cppjieba')` find the prebuilt module, ahead of any other one.
---@return boolean installed
function M.add_to_cpath()
  if not M.is_installed() then
    return false
  end
  local pattern = M.dir() .. '/?.dll'
  if not package.cpath:find(pattern, 1, true) then
    package.cpath = pattern .. ';' .. package.cpath
  end
  return true
end

-- Prefer the Windows tools: Git for Windows may put a GNU tar first on PATH,
-- which cannot extract zip archives.
local function system_tool(name)
  local path = (os.getenv('SystemRoot') or 'C:\\Windows') .. '\\System32\\' .. name .. '.exe'
  return vim.uv.fs_stat(path) and path or name
end

local function run(cmd)
  local ok, result = pcall(function()
    return vim.system(cmd, { text = true }):wait()
  end)
  if not ok then
    return false, tostring(result)
  end
  if result.code ~= 0 then
    return false, ('%s failed: %s'):format(cmd[1], vim.trim(result.stderr or ''))
  end
  return true
end

-- Download and unpack the prebuilt package.  Blocks until done.
---@param opts {force: boolean}|nil
---@return boolean ok, string|nil err
function M.install(opts)
  if not M.supported() then
    return false, 'prebuilt cppjieba is only available for 64-bit Windows; install it with `luarocks install cppjieba`'
  end
  if M.is_installed() and not (opts and opts.force) then
    return true
  end

  local dir = M.dir()
  local tmp = dir .. '.tmp'
  local zip = tmp .. '/cppjieba-win-x64.zip'
  vim.fn.delete(tmp, 'rf')
  vim.fn.mkdir(tmp, 'p')

  local ok, err = run({ system_tool('curl'), '-fsSL', '--retry', '2', '-o', zip, M.url })
  if ok then
    ok, err = run({ system_tool('tar'), '-xf', zip, '-C', tmp })
  end
  os.remove(zip)
  if ok then
    vim.fn.delete(dir, 'rf')
    ok, err = vim.uv.fs_rename(tmp, dir)
  end
  vim.fn.delete(tmp, 'rf')

  if not ok then
    return false, err
  end
  if not M.is_installed() then
    return false, 'the downloaded cppjieba archive is incomplete'
  end
  return true
end

return M
