component = require("component")
thread = require("thread")
serial = require("serialization")
event = require("event")
term = require("term")
require("math.BigNum")
modem = component.modem
modem.open(7000)
modem.open(7001)

hashrates = {}
block = nil
jreq = nil
function explode(d, p)
  local t, ll, l
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

function listen(timeout)
  local client, msg

  if timeout == nil then
    _, _, client, _, _, msg = event.pull("modem_message")
  else
    _, _, client, _, _, msg = event.pull(timeout, "modem_message")
  end

  return client, msg
end

function listentonode(c, timeout)
  local client, msg

  if timeout == nil then
    _, _, client, _, _, _, msg = event.pull("modem_message", nil, c)
  else
    _, _, client, _, _, _, msg = event.pull(timeout, "modem_message", nil, c)
  end

  return client, msg
end

print("Contacting node, announcing our IP")
modem.broadcast(2000, 7000, "CENTRALMINER_ANNOUNCE")

flag = false
while not flag do
  _, msg = listentonode(nil, 5)
  if msg == "OK" then
    print("Node registered ourselves succesfully, listening for new jobs")
    flag = true
  elseif msg ~= nil then
    print("Unable to contact masternode, aborting (got " .. (msg or "nil") .. ")")
    os.exit(1)
  end
end

function processNetworkMessage(...)
  local _, _, client, _, _, msg = ...
  if msg ~= nil then
    local parsed = explode("####", tostring(msg))
    if parsed[1] == "NJ" then
      block = serial.unserialize(parsed[2])
      jreq = client
      difficulty, _ = (BigNum.new(2) ^ BigNum.new(240) * 100) // block.target
      print("New job: #" .. block.uuid .. " at height " .. block.height .. " difficulty " .. tostring(difficulty))
      modem.broadcast(7001, block.uuid, BigNum.toHex(BigNum.new(block.target)))
    elseif parsed[1] == "HR" then
      hashrates[client] = tonumber(parsed[2])
    elseif parsed[1] == "NF" then
      print("BLOCK MINED! Nonce=" .. parsed[2])
      block.nonce = parsed[2]
      modem.send(jreq, 2000, 7000, "NEWBLOCK####" .. serial.serialize(block))
    end
  end
end

event.listen("modem_message", processNetworkMessage)

while true do
  if block ~= nil then
    modem.broadcast(7001, block.uuid, BigNum.toHex(BigNum.new(block.target)))
  end
  local sum = 0
  for k, v in pairs(hashrates) do
    sum = sum + v
    hashrates[k] = nil
  end
  print("Total hashrate: " .. sum .. " H/s")
  os.sleep(10)
end
