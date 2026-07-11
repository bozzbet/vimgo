# Setting Up Android Phone for Verus Mining

## Pre-Installation Requirements
Install Termux on the Android phone before running the miner.

## One-Line Install Command
Run this in Termux to update packages, install dependencies, install the miner, and save your config under a custom filename.

```bash
curl -fsSL https://raw.githubusercontent.com/bozzbet/vimgo/main/install_vim.sh | bash -s -- my-solo.json
```

If you want to provide your own wallet and worker name, you can also use:

```bash
curl -fsSL https://raw.githubusercontent.com/bozzbet/vimgo/main/install_vim.sh | bash -s -- my-solo.json YOUR_WALLET.YOUR_WORKER_NAME
```

When no worker name is provided, the installer uses the wallet prefix from `config.json` and generates a worker name in the format `WALLET.iVim-<deviceID>`. The device ID prefers Android serial properties when available, skips generic values like `localhost`, and falls back to the current time in `HHMMSSmmm` format.

```bash
curl -fsSL https://raw.githubusercontent.com/bozzbet/vimgo/main/install_vim.sh | bash
```

## Post-Install Procedure
The installer places `ccminer`, `vimgo.sh`, `vimstop.sh`, and your config file in the `~/ccminerd` directory on the phone.

## Edit the Config File
The config file is saved as my-solo.json (or config.json if you use the default name). The second argument sets the miner user field, so each phone can use its own worker name such as YOUR_WALLET.phone01.

```bash
cd ~/ccminerd
nano my-solo.json
```

Example config values include:
- pool name and pool URL
- wallet address and worker name
- threads
- API allow range

## How To Start The Miner
```bash
cd ~/ccminerd
./vimgo.sh my-solo.json
```

## How To Stop The Miner
```bash
cd ~/ccminerd
./vimstop.sh
```

## Check If The Miner Process Is Running
```bash
pgrep -a ccminer
```
