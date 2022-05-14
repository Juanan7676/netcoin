function explode(d, p)
    local t, ll
    t = {}
    ll = 0
    if (#p == 1) then
        return {p}
    end
    while true do
        l = string.find(p, d, ll, true) -- find the next d in the string
        if l ~= nil then -- if "not not" found then..
            table.insert(t, string.sub(p, ll, l - 1)) -- Save it in our array.
            ll = l + #d -- save just after where we found it for searching next time.
        else
            table.insert(t, string.sub(p, ll)) -- Save what's left in our array.
            break -- Break at end, as it should be, according to the lua manual.
        end
    end
    return t
end

function copy(obj, seen)
    if type(obj) ~= "table" then
        return obj
    end
    if seen and seen[obj] then
        return seen[obj]
    end
    local s = seen or {}
    local res = setmetatable({}, getmetatable(obj))
    s[obj] = res
    for k, v in pairs(obj) do
        res[copy(k, s)] = copy(v, s)
    end
    return res
end

function tableHas(t, elem)
    for _, e in pairs(t) do
        if e == elem then
            return true
        end
    end
    return false
end

function fromhex(str)
    return (str:gsub(
        "..",
        function(cc)
            return string.char(tonumber(cc, 16))
        end
    ))
end

function tohex(str)
    return (str:gsub(
        ".",
        function(c)
            return string.format("%02X", string.byte(c))
        end
    ))
end

function hexMod(hex, b)
    local mod = 0
    for c in hex:gmatch(".") do
        mod = (mod * 16 + tonumber(c, 16)) % b
    end
    return mod
end

function randomHex(length)
    local vars = {"0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F"}
    local str = ""
    for k = 1, length do
        str = str .. vars[math.random(1, #vars)]
    end
    return str
end

alpha_charset = {
    "0",
    "1",
    "2",
    "3",
    "4",
    "5",
    "6",
    "7",
    "8",
    "9",
    "A",
    "B",
    "C",
    "D",
    "E",
    "F",
    "G",
    "H",
    "I",
    "J",
    "K",
    "L",
    "M",
    "N",
    "O",
    "P",
    "Q",
    "R",
    "S",
    "T",
    "U",
    "V",
    "W",
    "X",
    "Y",
    "Z",
    "a",
    "b",
    "c",
    "d",
    "e",
    "f",
    "g",
    "h",
    "i",
    "j",
    "k",
    "l",
    "m",
    "n",
    "o",
    "p",
    "q",
    "r",
    "s",
    "t",
    "u",
    "v",
    "w",
    "x",
    "y",
    "z"
}

function randomUUID(length)
    local str = ""
    for k = 1, length do
        str = str .. alpha_charset[math.random(1, #alpha_charset)]
    end
    return str
end

function appendZeros(str, desiredLength)
    while #str < desiredLength do
        str = "0" .. str
    end
    return str
end

function trimZeros(str)
    local cp = str
    local remove = string.byte("0")
    for idx = 1, #cp do
        if cp:byte(1) == remove then
            cp = cp:sub(2, -1)
        else
            return cp
        end
    end
    return "0"
end

function compareHex(hex1, hex2)
    local h1 = trimZeros(hex1)
    local h2 = trimZeros(hex2)
    if #h1 > #h2 then
        return 1
    elseif #h1 < #h2 then
        return -1
    else
        for idx = 1, #h1 do
            if h1:byte(idx) < h2:byte(idx) then
                return -1
            elseif h1:byte(idx) > h2:byte(idx) then
                return 1
            end
        end
    end
    return 0
end

function minar(h, target, hashFunc, iterations)
    local nonce = randomUUID(16)
    h = tohex(hashFunc(h))
    while true do
        for k = 1, iterations do
            local hash = hashFunc(h .. nonce)
            if hash ~= nil then
                if (compareHex(tohex(hash), target) < 0) then
                    return true, nonce
                end
                nonce = randomUUID(16)
            end
            os.sleep(0) -- yield to avoid a crash
        end
        return false, false
    end
end
