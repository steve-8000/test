#!/bin/bash
source <(curl -s https://raw.githubusercontent.com/itrocket-team/testnet_guides/main/utils/common.sh)

printLogo

read -p "Enter WALLET name:" WALLET
echo 'export WALLET='$WALLET
read -p "Enter your MONIKER :" MONIKER
echo 'export MONIKER='$MONIKER
read -p "Enter your PORT (for example 17, default port=26):" PORT
echo 'export PORT='$PORT

# set vars
echo "export WALLET="$WALLET"" >> $HOME/.bash_profile
echo "export MONIKER="$MONIKER"" >> $HOME/.bash_profile
echo "export OG_CHAIN_ID="zgtendermint_16600-2"" >> $HOME/.bash_profile
echo "export OG_PORT="$PORT"" >> $HOME/.bash_profile
source $HOME/.bash_profile

printLine
echo -e "Moniker: \e[1m\e[32m$MONIKER\e[0m"
echo -e "Wallet: \e[1m\e[32m$WALLET\e[0m"
echo -e "Chain id: \e[1m\e[32m$OG_CHAIN_ID\e[0m"
echo -e "Node custom port: \e[1m\e[32m$OG_PORT\e[0m"
printLine
sleep 1

printGreen "1. Installing go..." && sleep 1
# install go, if needed
cd $HOME
VER="1.21.3"
wget "https://golang.org/dl/go$VER.linux-amd64.tar.gz"
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf "go$VER.linux-amd64.tar.gz"
rm "go$VER.linux-amd64.tar.gz"
[ ! -f ~/.bash_profile ] && touch ~/.bash_profile
echo "export PATH=$PATH:/usr/local/go/bin:~/go/bin" >> ~/.bash_profile
source $HOME/.bash_profile
[ ! -d ~/go/bin ] && mkdir -p ~/go/bin

echo $(go version) && sleep 1

source <(curl -s https://raw.githubusercontent.com/itrocket-team/testnet_guides/main/utils/dependencies_install)

printGreen "4. Installing binary..." && sleep 1
# download binary
# download binary
cd $HOME
rm -rf 0g-chain
wget -O 0gchaind https://github.com/0glabs/0g-chain/releases/download/v0.4.0/0gchaind-linux-v0.4.0
chmod +x $HOME/0gchaind
sudo mv $HOME/0gchaind $HOME/go/bin

printGreen "5. Configuring and init app..." && sleep 1
# config and init app
0gchaind config node tcp://localhost:${OG_PORT}657
0gchaind config keyring-backend os
0gchaind config chain-id zgtendermint_16600-2
0gchaind init $MONIKER --chain-id zgtendermint_16600-2
sleep 1
echo done

printGreen "6. Downloading genesis and addrbook..." && sleep 1
# download genesis and addrbook
wget -O $HOME/.0gchain/config/genesis.json https://server-5.itrocket.net/testnet/og/genesis.json
wget -O $HOME/.0gchain/config/addrbook.json https://server-5.itrocket.net/testnet/og/addrbook.json
sleep 1
echo done

printGreen "7. Adding seeds, peers, configuring custom ports, pruning, minimum gas price..." && sleep 1
# set seeds and peers
SEEDS="8f21742ea5487da6e0697ba7d7b36961d3599567@og-testnet-seed.itrocket.net:47656"
PEERS="80fa309afab4a35323018ac70a40a446d3ae9caf@og-testnet-peer.itrocket.net:11656,b3d5b28117047aa8806136b88b870f9271753cc0@65.109.30.101:34656,39d170baab8d8f3a906368e5727352154a1b2435@65.21.93.104:47656,961bebe185e25d3ba1db886385dbce165b8b45ac@148.251.135.220:26656,c0dab875b2e19d74a830b4a13393b004d8bf9504@84.21.171.218:12656,6c4d06820e4f14e256ce6386019dc227dcc0bc3e@62.146.231.100:656,b396ffad15690cbc01267c3513176e7865d9cfa8@62.169.31.35:26656,102368751ef7abb363830bd7e48f8ada6245ab15@95.111.224.140:12656,23e96ba46f8120735e6b5646a755f32a65bf381b@146.59.118.198:29156,fed05ab0e16603b6abbcfcb665ffef4e5850aa4d@157.173.99.206:12656,9a8da367ae4e31385cd00afe2315ea1910f50609@164.68.100.91:12656,9efd0ac7315cbadaf7f488272360741a5b91f28e@62.169.28.60:12656,16d33d0086c6f5d5a502e428ff3947980b00ecc6@37.27.172.60:26656,38bb09933a8f2175af407887fbb37945750ebd93@109.199.127.5:12656,d08764ae3f8c05297d905cffbf18a0d8ff93c169@37.27.127.220:16656,76cc5b9beaff9f33dc2a235e80fe2d47448463a7@95.216.114.170:26656,b7e1c1431de04bca1c7a530e8ea58ed173364c0d@83.171.249.52:656,f5c0019956c9849895da36a0defb553cc9d50ca9@158.220.123.90:12656,8b23640e0c93a93e6caa971c002b88096dd0fb57@167.86.94.135:12656,bad92a950179805d7962fff2edbeed9e85e0e9bb@159.69.72.177:12656,b5a3288693e5db00bf6fe46842a9cf591aa55811@37.27.134.110:51656"
sed -i -e "/^\[p2p\]/,/^\[/{s/^[[:space:]]*seeds *=.*/seeds = \"$SEEDS\"/}" \
-e "/^\[p2p\]/,/^\[/{s/^[[:space:]]*persistent_peers *=.*/persistent_peers = \"$PEERS\"/}" \
$HOME/.0gchain/config/config.toml

# set custom ports in app.toml
sed -i.bak -e "s%:1317%:${OG_PORT}317%g;
s%:8080%:${OG_PORT}080%g;
s%:9090%:${OG_PORT}090%g;
s%:9091%:${OG_PORT}091%g;
s%:8545%:${OG_PORT}545%g;
s%:8546%:${OG_PORT}546%g;
s%:6065%:${OG_PORT}065%g" $HOME/.0gchain/config/app.toml


# set custom ports in config.toml file
sed -i.bak -e "s%:26658%:${OG_PORT}658%g;
s%:26657%:${OG_PORT}657%g;
s%:6060%:${OG_PORT}060%g;
s%:26656%:${OG_PORT}656%g;
s%^external_address = \"\"%external_address = \"$(wget -qO- eth0.me):${OG_PORT}656\"%;
s%:26660%:${OG_PORT}660%g" $HOME/.0gchain/config/config.toml

# config pruning
sed -i -e "s/^pruning *=.*/pruning = \"custom\"/" $HOME/.0gchain/config/app.toml
sed -i -e "s/^pruning-keep-recent *=.*/pruning-keep-recent = \"100\"/" $HOME/.0gchain/config/app.toml
sed -i -e "s/^pruning-interval *=.*/pruning-interval = \"50\"/" $HOME/.0gchain/config/app.toml

# set minimum gas price, enable prometheus and disable indexing
sed -i 's|minimum-gas-prices =.*|minimum-gas-prices = "0ua0gi"|g' $HOME/.0gchain/config/app.toml
sed -i -e "s/prometheus = false/prometheus = true/" $HOME/.0gchain/config/config.toml
sed -i -e "s/^indexer *=.*/indexer = \"null\"/" $HOME/.0gchain/config/config.toml
sleep 1
echo done

# create service file
sudo tee /etc/systemd/system/0gchaind.service > /dev/null <<EOF
[Unit]
Description=og node
After=network-online.target
[Service]
User=$USER
WorkingDirectory=$HOME/.0gchain
ExecStart=$(which 0gchaind) start --home $HOME/.0gchain --log_output_console
Restart=on-failure
RestartSec=5
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
EOF

printGreen "8. Downloading snapshot and starting node..." && sleep 1
# reset and download snapshot
0gchaind tendermint unsafe-reset-all --home $HOME/.0gchain
if curl -s --head curl https://server-5.itrocket.net/testnet/og/og_2024-10-17_1521680_snap.tar.lz4 | head -n 1 | grep "200" > /dev/null; then
curl https://server-5.itrocket.net/testnet/og/og_2024-10-17_1521680_snap.tar.lz4 | lz4 -dc - | tar -xf - -C $HOME/.0gchain
else
echo "no snapshot founded"
fi

# enable and start service
sudo systemctl daemon-reload
sudo systemctl enable 0gd
sudo systemctl restart 0gd && sudo journalctl -u 0gd -f
