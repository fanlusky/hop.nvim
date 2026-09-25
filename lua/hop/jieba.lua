-- Optional Jieba-backed word targets.
--
-- This module deliberately does not require jieba.nvim at load time.  Hop keeps
-- its normal word motion available when the optional native dependency is not
-- installed.
local M = {}

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

---@param jieba table A jieba.nvim Jieba instance, or a compatible object.
---@return Regex
function M.regex(jieba)
  assert(jieba and type(jieba.cut) == 'function', 'a Jieba instance is required')
  return make_regex(jieba)
end

---@param opts Options
---@return Regex|nil, string|nil
function M.regex_from_jieba(opts)
  local ok, native = pcall(require, 'cppjieba')
  if not ok then
    return nil, 'cppjieba is not installed; install it with :Rocks install cppjieba'
  end

  local paths = opts and opts.jieba_paths
  if not paths then
    return nil, 'cppjieba paths are not configured; set opts.jieba_paths'
  end

  local ok_instance, native_instance = pcall(native.Jieba, paths.dict, paths.model, paths.user_dict, paths.idf, paths.stop_word)
  if not ok_instance or not native_instance then
    return nil, 'cppjieba could not initialize its native backend'
  end
  return M.regex({ cut = function(_, line) return native_instance:cut(line) end })
end

return M
