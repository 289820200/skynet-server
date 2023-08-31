-- local cjson = require "cjson"
-- cjson.encode_sparse_array(true, 1, 1)
-- cjson.encode_number_precision(14)

-- local packer = {}

-- function packer.pack (v)
-- 	return cjson.encode (v)
-- end

-- function packer.unpack (v)
-- 	return cjson.decode (v)
-- end

local json = require "db.dkjson"

local packer = {}

function packer.pack (v)
    return json.encode (v)
end

function packer.unpack (v)
    return json.decode (v)
end

return packer
