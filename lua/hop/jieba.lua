-- Optional Jieba-backed word targets.
--
-- This module deliberately does not require cppjieba at load time.  Hop keeps
-- its normal word motion available when the optional native dependency is not
-- installed.  On Windows a prebuilt module is used (see hop.jieba_install).
local M = {}

---@type table<string, table> Native cppjieba instances keyed by their paths.
local instances = {}

local function is_keyword(token)
  return token ~= '' and vim.fn.match(token, [[^\k]]) == 0
end

local function make_regex(jieba)
  local cached_line
  local cached_spans

  return {
    oneshot = false,
    match = function(s, jump_ctx)
      -- jump_target.lua calls match() with progressively shorter suffixes of
      -- the same line.  Tokenize the complete line once, then expose the next
      -- token relative to the suffix being searched.
      local full_line = jump_ctx and jump_ctx.line_ctx.line or s
      if cached_line ~= full_line then
        cached_line = full_line
        cached_spans = {}
        local offset = 0
        for _, token in ipairs(jieba:cut(full_line) or {}) do
          local length = #token
          if length > 0 then
            if is_keyword(token) then
              cached_spans[#cached_spans + 1] = { offset, offset + length }
            end
            offset = offset + length
          end
        end
      end

      local suffix_offset = #cached_line - #s
      for _, span in ipairs(cached_spans) do
        if span[1] >= suffix_offset then
          return span[1] - suffix_offset, span[2] - suffix_offset
        end
      end
    end,
  }
end

local function default_paths()
  local dict = vim.api.nvim_get_runtime_file('lua/cppjieba/dict/jieba.dict.utf8', true)[1]
  if not dict then
    return nil
  end
  local dir = vim.fn.fnamemodify(dict, ':h')
  return {
    dict = dict,
    model = dir .. '/hmm_model.utf8',
    user_dict = vim.fn.has('win32') == 1 and 'nul' or '/dev/null',
    idf = dir .. '/idf.utf8',
    stop_word = dir .. '/stop_words.utf8',
  }
end

---@param jieba table A jieba.nvim Jieba instance, or a compatible object.
---@return Regex
function M.regex(jieba)
  assert(jieba and type(jieba.cut) == 'function', 'a Jieba instance is required')
  return make_regex(jieba)
end

---@param opts Options
---@return Regex|nil, string|nil
function M.regex_from_jieba(opts)
  local install = require('hop.jieba_install')
  install.add_to_cpath()
  local ok, native = pcall(require, 'cppjieba')
  if not ok and install.supported() then
    -- First use without lazy.nvim's build step: fetch the prebuilt module.
    vim.notify('HopWordJieba: downloading prebuilt cppjieba...', vim.log.levels.INFO)
    local installed, err = install.install()
    if not installed then
      return nil, 'could not install cppjieba: ' .. err
    end
    install.add_to_cpath()
    ok, native = pcall(require, 'cppjieba')
  end
  if not ok then
    return nil, 'cppjieba is not installed; run :HopJiebaInstall or `luarocks install cppjieba`'
  end

  local paths = (opts and opts.jieba_paths) or install.paths() or default_paths()
  if not paths then
    return nil, 'cppjieba paths are not configured; set opts.jieba_paths'
  end

  -- Loading the dictionaries takes hundreds of milliseconds, so keep one native
  -- instance per set of paths for the whole session.
  local key = table.concat({ paths.dict, paths.model, paths.user_dict, paths.idf, paths.stop_word }, '\n')
  local native_instance = instances[key]
  if not native_instance then
    local ok_instance
    ok_instance, native_instance = pcall(native.Jieba, paths.dict, paths.model, paths.user_dict, paths.idf, paths.stop_word)
    if not ok_instance or not native_instance then
      return nil, 'cppjieba could not initialize its native backend'
    end
    instances[key] = native_instance
  end
  return M.regex({ cut = function(_, line) return native_instance:cut(line) end })
end

-- Load the dictionaries ahead of the first jump.  Errors are ignored here and
-- reported by the first HopWordJieba call instead.
---@param opts Options|nil Defaults to the options passed to hop.setup().
function M.preload(opts)
  M.regex_from_jieba(opts or require('hop').opts)
end

return M
