local sprotoparser = require "sprotoparser"

local proto = {}

local function load_proto_file(file_name)
    local f = io.open(file_name)
    local txt = f:read("*a")
    f:close()
    return txt
end

local c2s = load_proto_file("game/proto/c2s.lua")
-- print("c2s",c2s)
local s2c = load_proto_file("game/proto/s2c.lua")
-- print("s2c",s2c)
proto.c2s = sprotoparser.parse(c2s)

proto.s2c = sprotoparser.parse(s2c)

return proto
