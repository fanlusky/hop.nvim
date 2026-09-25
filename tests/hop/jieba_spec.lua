local eq = assert.are.same

describe('Jieba word regex', function()
  it('uses token starts and skips punctuation', function()
    local jieba = {
      cut = function(_, line)
        eq('你好，world！测试', line)
        return { '你好', '，', 'world', '！', '测试' }
      end,
    }
    local regex = require('hop.jieba').regex(jieba)
    local ctx = { line_ctx = { line = '你好，world！测试' } }

    local b, e = regex.match(ctx.line_ctx.line, ctx)
    eq({ 0, 6 }, { b, e })
    b, e = regex.match(ctx.line_ctx.line:sub(e + 1), ctx)
    eq({ 3, 8 }, { b, e })
    b, e = regex.match(ctx.line_ctx.line:sub(15), ctx)
    eq({ 3, 9 }, { b, e })
  end)
end)
