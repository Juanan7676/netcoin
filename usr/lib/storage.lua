local storage = {}

local component = require("component")
local serial = require("serialization")
local filesys = require("filesystem")
local shell = require("shell")
local term = require("term")

require("common")

local hashService = require("math.hashService")
hashService.constructor(function(data) return tohex(component.data.sha256(data)) end)

local utxoProvider = require("utreetxo.utxoProviderInMemory")
local updater = require("utreetxo.updater")
updater.constructor(utxoProvider.iterator)

storage.data = component.data
storage.disks = {}

local homereq = {["disks.txt"] = true, ["nodes.txt"] = "{}", ["contacts.txt"] = "{}", ["lb.txt"] = "error"}
local indexreq = {["index.txt"] = ""}
local walletreq = {["remutxo.txt"] = "", ["utxo.txt"] = "", ["walletremutxo.txt"] = "", ["walletutxo.txt"] = ""}

local getMount = function(addr)
	local f = filesys.mounts()
	for p, m in f do
		if p.address == addr then
			return m
		end
	end
end

function storage.generateIndex()
	local file = io.open(getMount(storage.indexDisk) .. "/index.txt", "w")
	for k = 1, 150000 do
		file:write("00000000000000000000000000000000XX")
	end
	file:close()
	os.execute("mkdir " .. getMount(storage.indexDisk) .. "/conflicts")
end

function storage.reloadDisks()
	local df = io.open("disks.txt", "r")
	if not df then
		return
	end
	local line = df:read()
	if not line then
		df:close()
		return
	end
	local arr = explode(",", line)
	storage.indexDisk = arr[2]
	line = df:read()
	if not line then
		df:close()
		return
	end
	arr = explode(",", line)
	storage.utxoDisk = arr[2]
	line = df:read()
	while line ~= nil do
		arr = explode(",", line)
		storage.disks[arr[1]] = arr[2]
		line = df:read()
	end
	df:close()
end

function storage.editDisks()
	local availDisks = {}
	for p, m in filesys.mounts() do
		if string.sub(m, 1, 4) == "/mnt" then
			availDisks[#availDisks + 1] = {
				mount = m,
				size = p.spaceTotal(),
				used = p.spaceUsed(),
				label = p.getLabel(),
				addr = p.address,
				usage = 0,
				oldusage = 0,
				name = nil,
				i = math.huge
			}
		end
	end

	local diskr = io.open("disks.txt", "r")
	if diskr then
		local disks = {}
		repeat
			local d = diskr:read()
			if not d then
				break
			end
			local arr = explode(",", d)
			disks[#disks + 1] = arr
		until not d or not string.find(d, ",")
		for i, d in ipairs(disks) do
			for j, ad in ipairs(availDisks) do
				if d[2] == ad.addr then
					ad.i = i
					ad.usage = math.min(i, 3)
					ad.oldusage = ad.usage
					ad.name = d[1]
				end
			end
		end
		diskr:close()
	end
	table.sort(
		availDisks,
		function(a, b)
			return a.i < b.i
		end
	)
	local tgpu = term.gpu()
	local seldisk = -1
	local function drawDisks()
		term.clear()
		tgpu.setForeground(0xFFFFFF)
		print("Disk editor")
		for i, j in ipairs(availDisks) do
			local ustring = " "
			tgpu.setForeground(0xFFFFFF)
			if j.usage == 1 then
				ustring = "I"
				tgpu.setForeground(0x00FF00)
			elseif j.usage == 2 then
				ustring = "W"
				tgpu.setForeground(0x00FFFF)
			elseif j.usage == 3 then
				ustring = "B"
				tgpu.setForeground(0xFFFF00)
			end
			print(
				(seldisk == i and "*" or " ") ..
					"[" ..
						ustring ..
							"] Disk " ..
								tostring(i) ..
									", size: " ..
										tostring(j.size) ..
											" bytes, used: " ..
												tostring(j.used) .. " bytes, free: " .. tostring(j.size - j.used) .. ' bytes, address: "' .. j.addr .. '"'
			)
		end
		tgpu.setForeground(0xFFFFFF)
	end
	local running = true
	local save = false
	while running do
		local d
		repeat
			drawDisks()
			print("Select disk to execute operation on, type q to quit or type s to save and quit: ")
			local o = string.sub(string.upper(term.read()), 1, -2)
			if o == "Q" or o == "S" then
				save = (o == "S")
				running = false
			end
			d = tonumber(o)
		until (d and availDisks[d]) or not running
		if not running then
			break
		end
		seldisk = d
		drawDisks()
		print(
			"Press U to unassign, I to assign as index disk, W to assign as wallet disk, B to assign as block disk and any other key to cancel"
		)
		local o = string.sub(string.upper(term.read()), 1, 1)
		if o == "U" then
			availDisks[seldisk].usage = 0
		elseif o == "I" then
			for i, j in ipairs(availDisks) do
				if j.usage == 1 then
					j.usage = 3
				end
			end
			availDisks[seldisk].usage = 1
		elseif o == "W" then
			for i, j in ipairs(availDisks) do
				if j.usage == 2 then
					j.usage = 3
				end
			end
			availDisks[seldisk].usage = 2
		elseif o == "B" then
			availDisks[seldisk].usage = 3
		end
		seldisk = -1
	end
	if not save then
		return false
	end
	local oidisk
	local nidisk
	local owdisk
	local nwdisk
	local hasBlockDisk
	for i, j in ipairs(availDisks) do
		if j.oldusage == 1 then
			oidisk = j
		elseif j.oldusage == 2 then
			owdisk = j
		end
		if j.usage == 1 then
			nidisk = j
		elseif j.usage == 2 then
			nwdisk = j
		end
		if not hasBlockDisk and j.usage == 3 then
			hasBlockDisk = true
		end
	end
	if not nidisk then
		print("Missing index disk!")
	end
	if not nwdisk then
		print("Missing wallet disk!")
	end
	if not hasBlockDisk then
		print("Missing a block disk!")
	end
	if not (nidisk and nwdisk and hasBlockDisk) then
		print("Press any key to continue...")
		term.pull("key_down")
		return false
	end
	print("Moving data...")
	local tmpdir = os.tmpname() .. "/"
	filesys.makeDirectory(tmpdir .. "oindex")
	filesys.makeDirectory(tmpdir .. "owallet")
	filesys.makeDirectory(tmpdir .. "nioblocks")
	filesys.makeDirectory(tmpdir .. "nwoblocks")
	local niwasow = false
	if oidisk ~= nidisk and oidisk then
		shell.execute("mv -v " .. getMount(oidisk.addr) .. "/* " .. tmpdir .. "oindex")
		if nidisk == owdisk then
			niwasow = true
			shell.execute("mv -v " .. getMount(nidisk.addr) .. "/* " .. tmpdir .. "owallet")
		else
			shell.execute("mv -v " .. getMount(nidisk.addr) .. "/* " .. tmpdir .. "nioblocks")
		end
		shell.execute("cp -rv " .. tmpdir .. "oindex/*" .. " " .. getMount(nidisk.addr))
		shell.execute("cp -rv " .. tmpdir .. (niwasow and "owallet/*" or "nioblocks/*") .. " " .. getMount(oidisk.addr))
	end
	if owdisk ~= nwdisk and owdisk then
		local towdisk = niwasow and oidisk or owdisk
		if not niwasow then
			shell.execute("mv -v " .. getMount(towdisk.addr) .. "/* " .. tmpdir .. "owallet")
		end
		shell.execute("mv -v " .. getMount(nwdisk.addr) .. "/* " .. tmpdir .. "nwoblocks")
		shell.execute("cp -rv " .. tmpdir .. "owallet/* " .. getMount(nwdisk.addr))
		shell.execute("cp -rv " .. tmpdir .. "nwoblocks/* " .. getMount(towdisk.addr))
	end
	print("Updating disks.txt...")
	local diskw = io.open("disks.txt", "w")
	diskw:write((oidisk and oidisk.name or "00") .. "," .. nidisk.addr .. "\n")
	diskw:write((owdisk and owdisk.name or "01") .. "," .. nwdisk.addr .. "\n")
	local i = 2
	for _, j in ipairs(availDisks) do
		if j.usage == 3 then
			if j.oldusage == 1 then
				diskw:write((nidisk and nidisk.name or appendZeros(tostring(i), 2)) .. "," .. j.addr .. "\n")
			elseif j.oldusage == 2 then
				diskw:write((nwdisk and nwdisk.name or appendZeros(tostring(i), 2)) .. "," .. j.addr .. "\n")
			else
				diskw:write((j.name or appendZeros(tostring(i), 2)) .. "," .. j.addr .. "\n")
			end
		end
		i = i + 1
	end
	diskw:close()
	print("Reloading disk configuration...")
	storage.reloadDisks()
	return true
end

function storage.setup(force)
	local hometbc = {}
	local indextbc = {}
	local wallettbc = {}
	local disktxtexists = not force
	if not force then
		print("Detecting missing configuration files...")
		for n, v in pairs(homereq) do
			if not filesys.exists(shell.getWorkingDirectory() .. "/" .. n) then
				hometbc[n] = n ~= "disks.txt" and v or nil
				print("Missing: " .. n)
				if n == "disks.txt" then
					print("disks.txt does not exist! Marking all index and wallet disk files as missing...")
					indextbc = indexreq
					wallettbc = walletreq
					disktxtexists = false
				end
			end
		end
		if #indextbc == 0 then
			print("Detecting missing index disk files...")
			storage.reloadDisks()
			if not storage.indexDisk then
				indextbc = indexreq
				print("No index disk definition found! Marking all files as missing...")
			else
				for n, v in pairs(indexreq) do
					if not filesys.exists(getMount(storage.indexDisk) .. "/" .. n) then
						indextbc[n] = v
						print("Missing: " .. n)
					end
				end
			end
			print("Detecting missing wallet disk files...")
			if not storage.utxoDisk then
				wallettbc = walletreq
				print("No wallet disk definition found! Marking all files as missing...")
			else
				for n, v in pairs(walletreq) do
					if not filesys.exists(getMount(storage.utxoDisk) .. "/" .. n) then
						wallettbc[n] = v
						print("Missing: " .. n)
					end
				end
			end
		end
	end
	if #hometbc == 0 and #indextbc == 0 and #wallettbc == 0 and disktxtexists and not force then
		return
	end
	if not disktxtexists then
		repeat
			print("Opening disk editor...")
		until storage.editDisks() or force
	end
	if force then
		return
	end
	print("Creating files...")
	for i, j in pairs(hometbc) do
		local h = io.open(i, "w")
		h:write(j)
		h:close()
	end
	for i, j in pairs(indextbc) do
		storage.generateIndex()
	end
	for i, j in pairs(wallettbc) do
		local h = io.open(getMount(storage.utxoDisk) .. "/" .. i, "w")
		h:write(j)
		h:close()
	end
end

if (storage.data == nil) then
	print("No data card present on device!")
end

function decomposePair(entry)
	return entry:sub(1, -3), entry:sub(33, -1)
end

function storage.loadIndex(uuid)
	local file, err = assert(io.open(getMount(storage.indexDisk) .. "/index.txt", "rb"))
	if file == nil then
		print(err)
	end
	if not uuid then
		file:close()
		return nil
	end

	local num = hexMod(tohex(storage.data.sha256(uuid)), 150000)
	file:seek("set", 34 * num)
	local data = file:read(34)
	local key, value = decomposePair(data)

	if key == "00000000000000000000000000000000" then
		file:close()
		return nil
	end
	if tohex(key) ~= uuid then -- Solve conflict
		local aux = io.open(getMount(storage.indexDisk) .. "/conflicts/" .. tohex(key) .. ".txt", "r")
		if aux == nil then
			file:close()
			return nil
		end
		local line = aux:read()
		local ret = nil
		while line ~= nil do
			local tmp = explode(",", line)
			if tmp[1] == uuid then
				ret = tmp[2]
				break
			end
			line = aux:read()
		end
		aux:close()
		file:close()
		return tohex(key), value
	end
	file:close()
	return tohex(key), value
end

function storage.loadRawIndex(uuid)
	local file = io.open(getMount(storage.indexDisk) .. "/index.txt", "rb")
	local num = hexMod(tohex(storage.data.sha256(uuid)), 150000)
	file:seek("set", 34 * num)
	local data = file:read(34)
	file:close()
	return data
end

function storage.saveIndex(uuid, disk)
	local i = storage.loadRawIndex(uuid) or "00000000000000000000000000000000"
	local key, _ = decomposePair(i)
	if key ~= "00000000000000000000000000000000" and tohex(key) ~= uuid then -- Solve conflict
		local file = io.open(getMount(storage.indexDisk) .. "/conflicts/" .. tohex(key) .. ".txt", "a")
		if file == nil then
			file = io.open(getMount(storage.indexDisk) .. "/conflicts/" .. tohex(key) .. ".txt", "w")
		end
		file:write(uuid .. "," .. disk .. "\n")
		file:close()
	else
		local file = io.open(getMount(storage.indexDisk) .. "/index.txt", "ab")
		local num = hexMod(tohex(storage.data.sha256(uuid)), 150000)
		file:seek("set", 34 * num)
		file:write(fromhex(uuid) .. disk)
		file:close()
	end
end

function storage.deleteIndex(uuid)
	-- Scenario 1: there are conflicts for this index, and the name of the conflict is equal to this
	local file = io.open(getMount(storage.indexDisk) .. "/conflicts/" .. uuid .. ".txt", "r")
	if file ~= nil then
		local line = file:read()
		local conflictuuids = {}
		while line ~= nil do
			local data = explode(",", line)
			if data[1] ~= uuid then
				table.insert(conflictuuids, line)
			end
			line = file:read()
		end
		file:close()
		filesys.remove(getMount(storage.indexDisk) .. "/conflicts/" .. uuid .. ".txt")
		if #conflictuuids == 0 then -- this was the only uuid in the conflict --> we must remove the index entry
			local num = hexMod(tohex(storage.data.sha256(uuid)), 150000)
			local indexFile = io.open(getMount(storage.indexDisk) .. "/index.txt", "ab")
			indexFile:seek("set", 34 * num)
			indexFile:write("0000000000000000000000000000000000")
			indexFile:close()
		else -- there were more conflicts: we write the other ones and we save the entry as the first one
			local arr = explode(",", conflictuuids[1])
			file = io.open(getMount(storage.indexDisk) .. "/conflicts/" .. arr[1] .. ".txt", "w")
			for _, v in ipairs(conflictuuids) do
				file:write(v .. "\n")
			end
			file:close()

			local num = hexMod(tohex(storage.data.sha256(arr[1])), 150000)
			local indexFile = io.open(getMount(storage.indexDisk) .. "/index.txt", "ab")
			indexFile:seek("set", 34 * num)
			indexFile:write(fromhex(conflictuuids[1]) .. conflictuuids[2])
			indexFile:close()
		end
		return
	end

	local key, value = decomposePair(storage.loadRawIndex(uuid))
	if tohex(key) ~= uuid then -- Scenario 2: there are conflicts for this index, but the name of the conflict is not equal to this
		local f = io.open(getMount(storage.indexDisk) .. "/conflicts/" .. tohex(key) .. ".txt", "r")
		if f == nil then
			return
		end
		local conflictuuids = {}
		local line = f:read()
		while line ~= nil do
			local data = explode(",", line)
			if data[1] ~= uuid then
				table.insert(conflictuuids, line)
			end
			line = f:read()
		end
		f:close()
		filesys.remove(getMount(storage.indexDisk) .. "/conflicts/" .. tohex(key) .. ".txt")
		f = io.open(getMount(storage.indexDisk) .. "/conflicts/" .. tohex(key) .. ".txt", "w")
		for _, v in ipairs(conflictuuids) do
			f:write(v .. "\n")
		end
		f:close()
	else -- Scenario 3: there are no conflicts for this index
		local num = hexMod(tohex(storage.data.sha256(uuid)), 150000)
		local indexFile = io.open(getMount(storage.indexDisk) .. "/index.txt", "ab")
		indexFile:seek("set", 34 * num)
		indexFile:write("0000000000000000000000000000000000")
		indexFile:close()
	end
end

function storage.loadBlock(uuid)
	local _, disk = storage.loadIndex(uuid)
	if disk == nil then
		return nil, "nonexistent index"
	end
	disk = storage.disks[disk]
	if disk == nil then
		return nil, "invalid index"
	end
	local file = io.open(getMount(disk) .. "/" .. uuid .. ".txt", "rb")
	local block = (serial.unserialize(storage.data.inflate(file:read("*a"))))
	file:close()
	return block
end

function storage.saveBlock(block)
	if storage.loadBlock(block.uuid) ~= nil then
		return
	end
	local data = storage.data.deflate(serial.serialize(block))
	for k, d in pairs(storage.disks) do
		local hdd = component.proxy(component.get(d))
		if (hdd.spaceTotal() - hdd.spaceUsed() >= data:len()) then
			local file = io.open(getMount(d) .. "/" .. (block.uuid) .. ".txt", "wb")
			file:write(data)
			file:close()
			storage.saveIndex(block.uuid, k)
			return
		end
	end
	error("[!] All disks are full, i'm unable to save block id " .. block.uuid)
	return nil
end

function storage.deleteBlock(uuid)
	local _, disk = storage.loadIndex(uuid)
	if disk == nil then
		return
	end
	disk = storage.disks[disk]
	if disk == nil then
		return
	end
	filesys.remove(getMount(disk) .. "/" .. uuid .. ".txt")

	storage.deleteIndex(uuid)
end

function saveUTX(tx_table)
	local file = io.open(getMount(storage.utxoDisk) .. "/wutxos.txt","w")
	file:write(serial.serialize(tx_table))
	file:close()
end

local saveUTXToCache = function(tx_table)
	local file = io.open(getMount(storage.utxoDisk) .. "/wutxos_cached.txt","w")
	file:write(serial.serialize(tx_table))
	file:close()
end

local loadUTX = function()
	local file = io.open(getMount(storage.utxoDisk) .. "/wutxos.txt","r")
	if file ~= nil then
		utxoProvider.setUtxos(serial.unserialize(file:read("*a")))
		file:close()
	end
end

local loadUTXFromCache = function()
	local file = io.open(getMount(storage.utxoDisk) .. "/wutxos_cached.txt","r")
	utxoProvider.setUtxos(serial.unserialize(file:read("*a")))
	file:close()
end

function storage.cacheutxo()
	saveUTXToCache(utxoProvider.getUtxos())

	local file = io.open("tb_cached.txt", "w")
	file:write(serial.serialize(cache.tb))
	file:close()
	file = io.open("pb_cached.txt", "w")
	file:write(serial.serialize(cache.tb))
	file:close()
	file = io.open("rt_cached.txt", "w")
	file:write(serial.serialize(cache.rt))
	file:close()
	file = io.open("pt_cached.txt", "w")
	file:write(serial.serialize(cache.pt))
	file:close()
end

function storage.restoreutxo()
	loadUTXFromCache()

	local file = io.open("tb_cached.txt", "r")
	cache.tb = serial.unserialize(file:read("*a"))
	file:close()
	file = io.open("pb_cached.txt", "r")
	cache.tb = serial.unserialize(file:read("*a"))
	file:close()
	file = io.open("rt_cached.txt", "r")
	cache.rt = serial.unserialize(file:read("*a"))
	file:close()
	file = io.open("pt_cached.txt", "r")
	cache.pt = serial.unserialize(file:read("*a"))
	file:close()
end

function storage.setuptmpenvutxo_cache()
	utxoProvider.setupTmpEnv()
	loadUTXFromCache()

	local file = io.open("tb_cached.txt", "r")
	cache._tb = serial.unserialize(file:read("*a"))
	file:close()
	file = io.open("pb_cached.txt", "r")
	cache._tb = serial.unserialize(file:read("*a"))
	file:close()
	file = io.open("rt_cached.txt", "r")
	cache._rt = serial.unserialize(file:read("*a"))
	file:close()
	file = io.open("pt_cached.txt", "r")
	cache._pt = serial.unserialize(file:read("*a"))
	file:close()
end

function storage.generateutxo()
	local file = io.open(getMount(storage.utxoDisk) .. "/wutxos.txt", "w")
	file:close()
	file = io.open(getMount(storage.utxoDisk) .. "/wutxos_cached.txt", "w")
	file:close()
end


storage.setup()
storage.reloadDisks()
loadUTX()

return storage
