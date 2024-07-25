# Reth Node Config

[![Telegram Chat][tg-badge]][tg-url]

This repo offers a shell script to deploy a **Reth node as well as Reth Exex's**

```
 ____      _   _       _   _           _         ____        _ _     _
|  _ \ ___| |_| |__   | \ | | ___   __| | ___   | __ ) _   _(_) | __| | ___ _ __
| |_) / _ \ __| '_ \  |  \| |/ _ \ / _\` |/ _ \ |  _ \| | | | | |/ _\`|/ _ \ '__|
|  _ <  __/ |_| | | | | |\  | (_) | (_| |  __/  | |_) | |_| | | | (_| |  __/ |
|_| \_\___|\__|_| |_| |_| \_|\___/ \__,_|\___|  |____/ \__,_|_|_|\__,_|\___|_|

🚀 Reth Node Builder v0.1 - Reth + Lighthouse + Moonstruct
```

> Why? Because ☠️ docker

### What?

- Simplifies the process of setting up a Reth node on a Linux system via a shell script.
- This script can:
  - Install: Reth, Lighthouse and Moonstruct.
  - Generate a JWT
  - Run moonsnap to download a snapshot and set up the Reth and Lighthouse daemon services.
  - Produce systemd services to run reth and lighthouse

## Start Here

> Note: Specific to Hetzner dedicated servers

### 0. Install the Repo

1. ssh into your instance
2. Install this repo
3. (optional) to use moonsnap `-m` place your `MOONSNAP_KEY` in the `.env` from [here](https://github.com/crebsy/moonsnap-downloadoor)
4. `cd reth-node-builder`
5. `chmod +x ./setup.sh`
6. Choose 1a or 1b

### 1a. Setup a full Node

`setup.sh -n <network> -m`

- Installs a Reth Node, Lighthouse CL Node and sets up system d services with moonsnap

### 1b.Setup a Full Node with an ExEx

`setup.sh -s https://github.com/AlignNetwork/blobster.git -m`

- `-s` option is the source of the reth, if you follow the [Reth examples repo](https://github.com/paradigmxyz/reth-exex-examples/tree/main) it runs reth with your exex so it will configure the correct options for the systemd

### 2. Starting Node

If the script ran successfully you should be able to run:

- `systemctl start reth-mainnet` - Start Reth Client
- `systemctl start lighthouse-mainnet` - Start Lighthouse Client
- `journalctl -u reth-mainnet -f` - Logs of Reth
- `journalctl -u lighthouse-mainnet -f`- Logs of Lighthouse

### Directory Structure:

The setup exists in reth-node-setup and the node data exists in /root/node

```
Directory Structure:
.
├── node
│ ├── reth (reth data)
│ └── secret (jwt secret)
├── reth-node-setup (this script home directory)
│ ├── node-sources (reth and lighthouse source code)
│ ├── services (your network services. This is where you put the run commands (reth node etc))
│ ├── .env (Moonsnap environment file)
│ └── node_setup.sh (this script)
└── ...

```

### Hosting / ssh

I tested this stack on:

1. Holesky: Hetzner AX42 for Holesky SSD: 2x512 Software: Raid1

> [!TIP]
> I selected Ubunutu 22 base on creation of instance, also added an ssh key with `ssh-keygen -t ed25519 -C "<Email>"`

### Notes:

1. On Hetzner I had interactive menus popup to restart defaults, I proceeded forwarded with them, I haven't looked into what exactly they are but it did not seem to affect the server.
2. Moonsnap saves a lot of time (only took around 2.5 hrs)

### 🗃️ Credits and Documentation:

- Reth: https://paradigmxyz.github.io/reth/
- Lighthouse: https://lighthouse-book.sigmaprime.io/
- Moonsnap: https://github.com/crebsy/moonsnap-downloadoor

[tg-badge]: https://img.shields.io/endpoint?color=neon&logo=telegram&label=chat&url=https%3A%2F%2Ftg.sumanjay.workers.dev%2Falign%5Fblobster
[tg-url]: https://t.me/align_blobster
