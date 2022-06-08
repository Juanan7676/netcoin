local sha = require("sha2")

local component = {}

component.data = {}
component.modem = {}
component.modem.address = "testing"

function component.data.sha256(str)
    return sha.hex_to_bin(sha.sha256(str))
end

return component