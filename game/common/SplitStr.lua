local string = require "string"
local function SplitStr(source, pattern, init)
    local lens = string.len(source)
    local lenp = string.len(pattern)

    local result = init or {}
    local c = 0

    local i = 1
    local start = 1
    while i <= lens - lenp + 1 do
        local found = true
        for j = 1, lenp do
            if string.byte(source, i + j - 1) ~= string.byte(pattern, j) then
                found = false
                break
            end
        end
        if found then
            if i > start then
                c = c + 1
                result[c] = string.sub(source, start, i - 1)
            end
            start = i + lenp
            i = start
        else
            i = i + 1
        end
    end
    if start <= lens then
        local same = false
        if lens - start + 1 == lenp then
            same = true
            for j = 1, lenp do
                if string.byte(source, start + j - 1) ~= string.byte(pattern, j) then
                    same = false
                    break
                end
            end
        end
        if not same then
            c = c + 1
            result[c] = string.sub(source, start, lens)
        end
    end
    result.c = c
    for i = c + 1, #result do
        result[i] = nil
    end
    return result
end

return SplitStr
