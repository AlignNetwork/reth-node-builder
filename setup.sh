#!/bin/bash -i

# Exit immediately if a command exits with a non-zero status
set -e

# Default verbose mode is off
VERBOSE=0
NETWORK_NAME=""
INSTALL_FULL_NODE=false
USE_MOONSNAP=false
REPO_NAME=""

show_intro() {
    cat << EOF
 ____      _   _       _   _           _         ____        _ _     _           
|  _ \ ___| |_| |__   | \ | | ___   __| | ___   | __ ) _   _(_) | __| | ___ _ __ 
| |_) / _ \ __| '_ \  |  \| |/ _ \ / _\` |/ _ \ |  _ \| | | | | |/ _\`|/ _ \ '__|
|  _ <  __/ |_| | | | | |\  | (_) | (_| |  __/  | |_) | |_| | | | (_| |  __/ |   
|_| \_\___|\__|_| |_| |_| \_|\___/ \__,_|\___|  |____/ \__,_|_|_|\__,_|\___|_|   
                                                          
🚀 Reth Node Builder v0.1 - Reth + Lighthouse + Moonsnap
------------------------------------------------
❔ What:
    Simplifies the process of setting up a Reth node on a Linux system.
    This script can:
      - Install: Reth, Lighthouse, & Moonsnap.
      - Generate a JWT
      - Run moonsnap to download a snapshot and set up the Reth and Lighthouse daemon services.
------------------------------------------------
🗃️ Credits and Documentation:
    Reth-node-builder (this repo): https://github.com/alignnetwork/reth-node-builder
    Reth: https://paradigmxyz.github.io/reth/
    Lighthouse: https://lighthouse-book.sigmaprime.io/
    Moonsnap: https://github.com/crebsy/moonsnap-downloadoor
------------------------------------------------
EOF
}

setup_services() {
  local services_dir="/root/reth-node-builder/services/$NETWORK_NAME"
  mkdir -p "$services_dir"

  # Determine Reth execution path and working directory based on RETH_SOURCE
  echo $RETH_SOURCE
 local reth_exec_path
  local reth_working_dir=""
  if [ -z "$RETH_SOURCE" ] || [ "$RETH_SOURCE" = "https://github.com/paradigmxyz/reth" ]; then
    reth_exec_path="/root/.cargo/bin/reth"
  elif [[ "$RETH_SOURCE" == http* ]]; then
    REPO_NAME=$(basename -s .git "$RETH_SOURCE")
    reth_exec_path="cargo run --bin exex --release --"
    reth_working_dir="WorkingDirectory=/root/reth-node-builder/node-sources/$REPO_NAME"
  else
    # Local folder
    reth_exec_path="cargo run --bin exex --release --"
    reth_working_dir="WorkingDirectory=/root/reth-node-builder/node-sources/$RETH_SOURCE"
  fi

  # Create Reth service file
  cat > "$services_dir/reth-${REPO_NAME}-${NETWORK_NAME}.service" << EOF
            [Unit]
            Description=Reth Ethereum Client
            After=network.target

            [Service]
            Type=simple
            User=root
            $reth_working_dir
            ExecStart=$reth_exec_path node --network $NETWORK_NAME --full --datadir /root/node/reth --authrpc.jwtsecret /root/node/secret/jwt.hex --http --http.api all
            Restart=on-failure
            RestartSec=5

            [Install]
            WantedBy=multi-user.target
EOF

    # Create Lighthouse service file
  cat > "$services_dir/lighthouse-${REPO_NAME}-${NETWORK_NAME}.service" << EOF
          [Unit]
          Description=Lighthouse Ethereum Client
          After=network.target

          [Service]
          Type=simple
          User=root
          ExecStart=/root/.cargo/bin/lighthouse bn --network $NETWORK_NAME --datadir /root/node/lighthouse --execution-endpoint http://localhost:8551 --execution-jwt /root/node/secret/jwt.hex --checkpoint-sync-url https://sync-mainnet.beaconcha.in
          Restart=on-failure
          RestartSec=5

          [Install]
          WantedBy=multi-user.target
EOF
  # Setup services
  setup_service "reth-$REPO_NAME-$NETWORK_NAME"
  setup_service "lighthouse-$REPO_NAME-$NETWORK_NAME"

  if [ $? -eq 0 ]; then
      systemctl daemon-reload
      echo "✅ Systemd daemon reloaded."
  else
      echo "❌ Failed to setup one or both services."
  fi
}


# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
  return $?
}

# Function to run commands based on verbosity
run_command() {
  local cmd_name=$(echo "$1" | cut -d' ' -f1)
  echo "Running $cmd_name..."
  if [ $VERBOSE -eq 1 ]; then
      "$@"
  else
      "$@" > /dev/null 2>&1
  fi
  echo "$cmd_name finished."
}

# Function to echo based on verbosity
verbose_echo() {
    if [ $VERBOSE -eq 1 ]; then
        echo "$@"
    fi
}


# Install Rust
install_rust() {
    echo "Installing Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source $HOME/.cargo/env
    source ~/.bashrc
    # echo the cargo version
    echo "Cargo version: $(cargo --version)"
    echo "✅ Rust installation completed."
}

# Install Reth
install_reth() {
  echo "Installing dependencies..."
  apt-get update  > /dev/null 2>&1
  apt-get install -y libclang-dev pkg-config build-essential > /dev/null 2>&1
  echo "Dependencies installed."
    # Default Paradigm Reth repo
    cd /root/reth-node-builder/node-sources
  if [ "$RETH_SOURCE" = "https://github.com/paradigmxyz/reth" ] || [ "$REPO_NAME" = "reth" ]; then
    if command_exists reth; then
      echo "✅ Reth already installed."
    else
      if [ -d "reth" ]; then
        echo "✅ Reth folder already exists"
      else
        git clone https://github.com/paradigmxyz/reth
        cd reth
        echo "Installing Reth..."
        cargo install --locked --path bin/reth --bin reth
      fi
    fi
  elif [[ "$RETH_SOURCE" == http* ]]; then
    REPO_NAME=$(basename -s .git "$RETH_SOURCE")
    echo "Installing Modified Reth from $RETH_SOURCE"
    # GitHub ExEx repo
    if [ -d "reth" ]; then
      echo "✅ Reth folder already exists."
    fi
    if [ -d "$REPO_NAME" ]; then
      echo "✅ $REPO_NAME folder already exists."
    else
      cd /root/reth-node-builder/node-sources
      REPO_NAME=$(basename -s .git "$RETH_SOURCE")
      git clone "$RETH_SOURCE" "$REPO_NAME"
      cd "$REPO_NAME"
    fi
  else
    echo "Installing Modified Reth from local $RETH_SOURCE"
    # Local ExEx folder
    cd /root/reth-node-builder/node-sources
    if [ -d "$RETH_SOURCE" ]; then
      cd "$RETH_SOURCE"
    else
      echo "ℹ️ Folder '$RETH_SOURCE' not found in /root/reth-node-builder/node-sources."
      mkdir -p /root/reth-node-builder/node-sources/"$NETWORK_NAME"
    fi
  fi
  echo "✅ Reth installation completed."
}

# Install Lighthouse
install_lighthouse() {
    echo "Installing Lighthouse dependencies..."
    run_command apt-get update
    run_command apt-get install -y git gcc g++ make cmake llvm-dev clang
    echo "Dependencies installed."
    echo "Cloning Lighthouse repository..."
    cd /root/reth-node-builder/node-sources
    git clone https://github.com/sigp/lighthouse.git
    cd /root/reth-node-builder/node-sources/lighthouse
    git checkout stable
    echo "Building Lighthouse..."
    run_command make
    echo "Lighthouse installation completed."
}

generate_jwt() {
    local jwt_path="/root/node/secret/jwt.hex"
    if [ -f "$jwt_path" ]; then
        echo "✅ JWT file already exists at $jwt_path"
    else
        echo "🔑 Generating JWT..."
        mkdir -p /root/node/secret
        openssl rand -hex 32 | tr -d "\n" | tee "$jwt_path" > /dev/null
        echo "🔐 JWT generated and saved to $jwt_path"
    fi
}

# Setup service file
setup_service() {
    local service_name=$1
    local service_file="/root/reth-node-builder/services/${NETWORK_NAME}/${service_name}.service"
    local service_path="/etc/systemd/system/${service_name}.service"

    echo "🔧 Setting up ${service_name} service... for ${NETWORK_NAME^^} network"
    if [ -f "$service_file" ]; then
        if cp "$service_file" "$service_path"; then
            chown root:root "$service_path"
            chmod 644 "$service_path"
            echo "✅ ${service_name} service for ${NETWORK_NAME^^} network installed and permissions set."
        else
            echo "❌ Failed to copy ${service_name} service file. Please check permissions and try again."
            return 1
        fi
    else
        echo "❌ ${service_name} service file not found. Make sure '${service_file}' is in the same directory as this script."
        return 1
    fi
}


# Function to set up moonsnap
setup_moonsnap() {
    echo "Setting up moonsnap..."
    curl https://dl.moonsnap.xyz/moonsnap -o /usr/local/bin/moonsnap
    chmod +x /usr/local/bin/moonsnap
    
    # Source the environment file
    source /root/reth-node-builder/.env
    
    if [ -z "$MOONSNAP_KEY" ]; then
        echo "Error: MOONSNAP_KEY not found in environment file, get one from https://github.com/crebsy/moonsnap-downloadoor/tree/main"
        exit 1
    fi
        
    echo "Downloading Reth snapshot using moonsnap..."
    /usr/local/bin/moonsnap "$MOONSNAP_KEY" /root/node/reth
    
    echo "Moonsnap download complete."
}



show_completion_message() {
    cat << EOF

--------------------------------------------------------------------------------

ℹ️  Naming: services are: reth-${NETWORK_NAME} and lighthouse-${NETWORK_NAME}

ℹ️  Data directories:
    Reth: /root/node/reth
    Lighthouse: /root/node/lighthouse
    JWT: /root/node/secret/jwt.hex

ℹ️  To start Reth and Lighthouse services, run the following commands: 
    $ systemctl start reth-${NETWORK_NAME}
    $ systemctl start lighthouse-${NETWORK_NAME}

ℹ️  To check the status of Reth and Lighthouse services, run the following commands:
    $ systemctl status reth-${NETWORK_NAME}
    $ systemctl status lighthouse-${NETWORK_NAME}

ℹ️  To view the logs of Reth and Lighthouse services, run the following commands:
    $ journalctl -u reth-${NETWORK_NAME} -f
    $ journalctl -u lighthouse-${NETWORK_NAME} -f

--------------------------------------------------------------------------------
EOF
}



show_help() {
    cat << EOF
Help: Generally you want to modify the daemon services. 

Directory Structure:
.
├── node
│   ├── reth (reth data)
│   └── secret (jwt secret)
├── reth-node-builder (this script home directory)
│   ├── node-sources (reth and lighthouse source code)
│   ├── services (your network services. This is where you put the run commands (reth node etc))
│   ├── .env (Moonsnap environment file)
│   └── node_setup.sh (this script)
└── ...

For more detailed information, refer to the documentation: https://github.com/alignnetwork/reth-node-builder

EOF
}

# Function to display usage
usage() {
  cat << EOF
Usage: $0 [-v] -s <RETH_SOURCE> -n <NETWORK_NAME> -m
  -v: Enable verbose mode
  -s: Specify Reth source:
      - No argument: Use default Paradigm Reth repo
      - GitHub URL: Use specified ExEx repo
      - Local folder name: Use local ExEx source
  -n: Specify the network name (e.g., mainnet, holesky, holesky-blobster-exex)
  -e: Examples
  -m: Use moonsnap for full node
  -h: Show more information help message
EOF
}

example_cmds() {
    cat << EOF
Example commands for using this script:

1. Install a full node for mainnet:
   setup.sh -n mainnet

2. Install a full node for mainnet with moonsnap:
   setup.sh -s -n mainnet -m

3. Install a full node for Holesky testnet:
   setup.sh -s -n holesky

4. Install ExEx for holesky testnet:
   setup.sh -s https://github.com/AlignNetwork/blobster.git -n holesky

5. Install ExEx for mainnet:
   setup.sh -s https://github.com/AlignNetwork/blobster.git -n mainnet

6. Install ExEx for mainnet with moonsnap:
   setup.sh -s https://github.com/AlignNetwork/blobster.git -n mainnet -m

7. Install ExEx from local:
   setup.sh -s blobster-local -n holesky -m

8. Show this help message:
   setup.sh -h

9. Run any command in verbose mode by adding -v, for example:
   setup.sh -v -f -n holesky

EOF
}


# Main Function

# Parse command line options
while getopts ":vn:hs:me" opt; do
  case $opt in
    v) VERBOSE=1 ;;
    n) NETWORK_NAME=$OPTARG ;;
    h) show_intro; exit 0 ;;
    s) RETH_SOURCE=$OPTARG ;;
    m) USE_MOONSNAP=true ;;
    e) example_cmds; exit 0 ;;
    \?) echo "Invalid option: -$OPTARG" >&2; usage; exit 1 ;;
    :) echo "Option -$OPTARG requires an argument." >&2; usage; exit 1 ;;
  esac
done

show_intro
# Check if network name is provided
if [ -z "$NETWORK_NAME" ]; then
  echo "ℹ️ Network name (-n) not set, using mainnet."
  NETWORK_NAME="mainnet"
fi

if [ -z "$RETH_SOURCE" ]; then
    # Default to Paradigm Reth repo if no source is specified
    RETH_SOURCE="https://github.com/paradigmxyz/reth"
    REPO_NAME="reth"
elif [ "$RETH_SOURCE" = "https://github.com/paradigmxyz/reth" ]; then
    REPO_NAME="reth"
elif [[ "$RETH_SOURCE" == http* ]]; then
    REPO_NAME=$(basename -s .git "$RETH_SOURCE")
    echo " Detected Modified (ExEx) Reth  source from github"
else
    echo "Installing Modified Reth from local $RETH_SOURCE"
    # Local ExEx folder
    cd /root/reth-node-builder/node-sources
    if [ -d "$RETH_SOURCE" ]; then
      cd "$RETH_SOURCE"
    else
      echo "ℹ️ Folder '$RETH_SOURCE' not found in /root/reth-node-builder/node-sources."
    fi
    REPO_NAME=$(basename -s .git "$RETH_SOURCE")
fi


echo "Starting installation process..."


if ! command_exists cargo; then
    install_rust
fi

install_reth

if ! command_exists lighthouse; then
    install_lighthouse
fi

generate_jwt
setup_services

# Setup Moonsnap if requested
if [ "$USE_MOONSNAP" = true ]; then
    setup_moonsnap
fi

echo "🎉 Node installation completed successfully!"
show_completion_message