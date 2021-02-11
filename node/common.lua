function explode(d,p)
  local t, lledit 
  t={}
  ll=0
  if(#p == 1) then return {p} end
    while true do
      l=string.find(p,d,ll,true) -- find the next d in the string
      if l~=nil then -- if "not not" found then..
        table.insert(t, string.sub(p,ll,l-1)) -- Save it in our array.
        ll=l+#d -- save just after where we found it for searching next time.
      else
        table.insert(t, string.sub(p,ll)) -- Save what's left in our array.
        break -- Break at end, as it should be, according to the lua manual.
      end
    end
  return t
end

function tableHas(t,elem)
    for _,e in pairs(t) do
        if e == elem then return true end
    end
    return false
end

function fromhex(str)
    return (str:gsub('..', function (cc)
        return string.char(tonumber(cc, 16))
    end))
end

function tohex(str)
    return (str:gsub('.', function (c)
        return string.format('%02X', string.byte(c))
    end))
end

function hexMod(hex,b)
    local mod = 0
    for c in hex:gmatch(".") do
        mod = (mod*16+tonumber(c,16))%b
    end
    return mod
end

function randomHex(length)
    local vars = {"0","1","2","3","4","5","6","7","8","9","A","B","C","D","E","F"}
    local str = ""
    for k=1,length do
        str = str .. vars[math.random(1,#vars)]
    end
    return str
end

function randomUUID(length)
    local vars = {"0","1","2","3","4","5","6","7","8","9","A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z","a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z"}
    local str = ""
    for k=1,length do
        str = str .. vars[math.random(1,#vars)]
    end
    return str
end