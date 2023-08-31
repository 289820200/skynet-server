local sharedata = require "skynet.sharedata"

local function get_intl_str(key)
    local settings = sharedata.query "settings_data"
    local intl_str = settings.intl_str
    if intl_str[key] then
        return intl_str[key].content
    else
        return nil
    end
end 

return get_intl_str