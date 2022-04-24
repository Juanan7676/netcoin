os.execute("rm -r usr")

baseDir = 'https://raw.githubusercontent.com/Juanan7676/netcoin/master/'

os.execute('mkdir usr')
os.execute('mkdir usr/bin')
os.execute('mkdir usr/lib')
os.execute('mkdir usr/lib/math')

os.execute('wget '..baseDir.."usr/bin/miner.lua usr/bin/miner.lua")
os.execute('wget '..baseDir.."usr/bin/minerCentral.lua usr/bin/minerCentral.lua")
os.execute('wget '..baseDir.."usr/bin/node.lua usr/bin/node.lua")
os.execute('wget '..baseDir.."usr/bin/nodesrv.lua usr/bin/nodesrv.lua")

os.execute('wget '..baseDir.."usr/lib/math/BigNum.lua usr/lib/math/BigNum.lua")
os.execute('wget '..baseDir.."usr/lib/common.lua usr/lib/common.lua")
os.execute('wget '..baseDir.."usr/lib/minerNode.lua usr/lib/minerNode.lua")
os.execute('wget '..baseDir.."usr/lib/netcraftAPI.lua usr/lib/netcraftAPI.lua")
os.execute('wget '..baseDir.."usr/lib/nodenet.lua usr/lib/nodenet.lua")
os.execute('wget '..baseDir.."usr/lib/protocol.lua usr/lib/protocol.lua")
os.execute('wget '..baseDir.."usr/lib/storage.lua usr/lib/storage.lua")
os.execute('wget '..baseDir.."usr/lib/wallet.lua usr/lib/wallet.lua")