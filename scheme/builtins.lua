local builtins = {}

local util = require "scheme.util"
local types = require "scheme.types"

--[[
-- Basic stuff
--]]

-- Interop would pass Lua's print lists as tables, which don't print well,
-- so we make our own print.
function builtins.print(self, args)
    for i = 1, #args do
        args[i] = args[i]:type() == "string" and
                        args[i]:getval()
                     or tostring(args[i])
    end

    print(table.unpack(args))
end

function builtins.format(self, args)
    util.expect_argc_min(self, 1, #args)

    local fargs = {}
    for i = 2, #args do
        if args[i]:type() ~= "string" and args[i]:type() ~= "number" then
            table.insert(fargs, tostring(args[i]))
        else
            table.insert(fargs, args[i]:getval())
        end
    end

    return types.mkstring(string.format(args[1]:getval(), table.unpack(fargs)))
end

builtins["to-string"] = function(self, args)
    util.expect_argc(self, 1, #args)

    return types.mkstring(tostring(args[1]))
end

--[[
-- Number stuff
--]]
local function numeric_primitive(op)
    return function(self, args)
        util.expect_argc(self, 2, #args)

        local a, b = args[1], args[2]

        util.expect(a, "number", "invalid operand type")
        util.expect(b, a:type(), "operand type mismatch")

        return types.mknumber(op(a:getval(), b:getval()))
    end
end

local function unary_numeric_primitive(op)
    return function(self, args)
        util.expect_argc(self, 1, #args)
        util.expect(args[1], "number", "invalid operand type")

        return types.mknumber(op(args[1]:getval()))
    end
end


builtins["+"] = numeric_primitive(function(a, b) return a + b end)
builtins["-"] = numeric_primitive(function(a, b) return a - b end)
builtins["*"] = numeric_primitive(function(a, b) return a * b end)
builtins["/"] = numeric_primitive(function(a, b) return a / b end)
builtins["%"] = numeric_primitive(function(a, b) return a % b end)
builtins["^"] = numeric_primitive(function(a, b) return a ^ b end)

builtins["neg"] = unary_numeric_primitive(function(a) return -a end)

--[[
-- List stuff
--]]
function builtins.list(self, args)
    return types.mklist{table.unpack(args)}
end

function builtins.cons(self, args)
    util.expect_argc(self, 2, #args)
    util.expect(args[2], "list")

    return types.mklist{args[1], table.unpack(args[2]:getval())}
end

function builtins.car(self, args)
    util.expect_argc(self, 1, #args)
    util.expect(args[1], "list")
    util.ensure(args[1], #args[1]:getval() > 0, "can not car on empty list")

    return args[1]:getval()[1]
end

function builtins.cdr(self, args)
    util.expect_argc(self, 1, #args)
    util.expect(args[1], "list")

    local tail = {}

    for i = 2, #args[1]:getval() do
        table.insert(tail, args[1]:getval()[i])
    end

    return types.mklist(tail)
end

function builtins.length(self, args)
    util.expect_argc(self, 1, #args)
    util.expect(args[1], {"list", "string"})

    return types.mknumber(#args[1]:getval())
end

builtins["pair?"] = function(self, args)
    util.expect_argc(self, 1, #args)
    util.expect(args[1], "list")

    return types.mkbool(#args[1]:getval() == 2)
end

builtins["null?"] = function(self, args)
    util.expect_argc(self, 1, #args)
    util.expect(args[1], "list")

    return types.mkbool(#args[1]:getval() == 0)
end

builtins["not"] = function(self, args)
    util.expect_argc(self, 1, #args)
    util.expect(args[1], "boolean")

    return types.mkbool(not args[1]:getval())
end

--[[
-- Type stuff
--]]
local function is_type(typ)
    return function(self, args)
        util.expect_argc(self, 1, #args)

        return types.mkbool(args[1]:type() == typ)
    end
end

for i, t in ipairs{"atom",
                   "list",
                   "number",
                   "string",
                   "boolean",
                   "character",
                   "function"} do
    builtins[t .. "?"] = is_type(t)
end

function builtins.type(self, args)
    util.expect_argc(self, 1, #args)

    return types.mkstring(args[1]:type())
end


--[[
-- Comparison stuff
--]]
builtins["="] = function(self, args)
    util.expect_argc(self, 2, #args)

    local a, b = args[1], args[2]

    util.expect(a, {"number",
                    "string",
                    "bool",
                    "list",
                    "character"}, "invalid operand type")

    -- No type coercion
    util.expect(b, a:type(), "operand type mismatch")

    if a:type() == "number" or
       a:type() == "string" or
       a:type() == "character" or
       a:type() == "bool" then
        return types.mkbool(a:getval() == b:getval())
    else
        local av, bv = a:getval(), b:getval()

        if #av ~= #bv then
            return types.mkbool(false)
        end

        for i = 1, #av do
            if not builtins["="](self, {av[i], bv[i]}):getval() then
                return types.mkbool(false)
            end
        end

        return types.mkbool(true)
    end
end

builtins["!="] = function(self, args)
    return builtins["not"](self, {builtins["="](self, args)})
end

builtins["<"] = function(self, args)
    util.expect_argc(self, 2, #args)

    local a, b = args[1], args[2]

    util.expect(a, {"number", "string"}, "invalid operand type")
    util.expect(b, a:type(), "operand type mismatch")

    return types.mkbool(a:getval() < b:getval())
end

builtins["<="] = function(self, args)
    util.expect_argc(self, 2, #args)

    return builtins["not"](self, {builtins["<"](self, {args[2], args[1]})})
end

builtins[">"] = function(self, args)
    util.expect_argc(self, 2, #args)

    return builtins["<"](self, {args[2], args[1]})
end

builtins[">="] = function(self, args)
    return builtins["not"](self, {builtins["<"](self, args)})
end

return builtins