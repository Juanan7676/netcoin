# What's NetCoin?
NetCoin is a cryptocurrency designed for OpenComputers, a Minecraft mod that adds computers in the game. It follows Bitcoin's original philosophy: a completely decentralized network of nodes, each one maintaining a ledger with everyone's transactions, grouped into blocks that miners need to create solving the proof-of-work (PoW).

# Wait, mining? Isn't that going to slow my server?
No! OpenComputers devs already thought about people using a lot of computers trying to lag the server. Computers execute their code on four separate threads, away from the server main thread and only execute code there on critical sections (e.g. activating a redstone component or breaking a block). In this sense, NetCoin doesn't interact with the world in any way, so the main server thread will not slow down by miners.
In addition, computer worker threads have a low priority, so if there are too much computers, they will slow down. This isn't a problem for the coin's protocol, since mining rewards are a function of your hashing power share out of the total of the network, not raw hashrate; if everyone slows down, your payrate will be the same given that your percentaje of hashrate is the same.
Nevertheless, mining does consume a LOT of power, if mining becomes a problem, server owners can increase power consumption of SHA-256 hashing, forcing some miners to leave.

# What's the crypto behind it?
It uses Elliptic Curve Digital Signature Algorithm (ECDSA) to sign transactions and SHA-256 as a PoW. Cryptographic functions are not implemented by software, but OpenComputers provides a component (Data Card) that provides an API to run these functions. That makes cryptography extremely efficient, since it runs directly on Java Code and not by the Lua VM.

# Protocol details? Block time? Transaction fees?
The details of the protocol itself can be found on netcoin.txt. Block time is about 5 minutes; this is a trade-off between transaction speed (who wants to wait 30 minutes for that NTC payment to be confirmed in order to receive those 3 diamonds?) and space (computers have a limited disk space, so blockchain shouldn't grow too fast).
NetCoin is a deflationary currency, meaning that block rewards are cut in half every 5000 blocks. There will be a point where miner's only incentive will be transaction fees. This feature hasn't been implemented yet, but it is planned on the future.

# I want to run this crypto!
Great! Use wget or pastebin command from OpenOS with an Internet Card to download the code into one of your computers. Once you have it, you can transfer it in-game via floppy disks to as many computers as wou want. You will need:
- A Data Card for using cryptography
- 3-4 raids full of Tier 3 Hard Drives (4MB) to store the blockchain
- Minimum 4MB of RAM

Run a node. It will automatically set up a wallet for you generating a public/private keypair. You will want to share your pubkey stored in wallet.pk, this is your official NetCoin address in which you will receive money. NEVER SHARE YOUR SECRET KEY STORED IN WALLET.SK! You will need to provide at least one node IP address (modem address) for it to connect to the network. It will automatically synchronize with the rest of the network: blocks, other nodes known...
To be a miner, you need a node and enable "isMiner" variable. Then you need a mining controller computer connected to the node. Finally, you will connect all your mining computers to the controller, and use "mine" command on the node. You're mining now!
