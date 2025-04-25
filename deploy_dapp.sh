#!/bin/bash

if [ $# != 1 ]; then
    echo "Missing parameters: <path_to_cartesi_dapp>"
    exit 1
fi

# 1) get machine hash
DAPP_PATH=$1
MACHINE_HASH_PATH=${DAPP_PATH}/.cartesi/image/hash
if [ ! -e $MACHINE_HASH_PATH ]; then
    echo "Build the DApp first."
    exit 1
fi

MACHINE_HASH=`xxd -p -u -c 64 $MACHINE_HASH_PATH`
MACHINE_HASH_0x="0x$MACHINE_HASH"
echo -e "Deploying for machine:  $MACHINE_HASH_0x\n"


DEPLOYER_CONTRACT_ADDR="0x9E32e06Fd23675b2DF8eA8e6b0A25c3DF6a60AbC"
DAPP_OWNER_ADDR="0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"
DAPP_OWNER_PK="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
RPC_URL="http://localhost:8545"
TX_RECEIPT="deploy_tx_receipt.json"

# 2) deploy the DApp
docker run --rm --net="host" ghcr.io/foundry-rs/foundry "cast send --json --private-key $DAPP_OWNER_PK --rpc-url $RPC_URL $DEPLOYER_CONTRACT_ADDR \"deployContracts(address _authorityOwner, address _dappOwner, bytes32 _templateHash, bytes32 _salt)\" $DAPP_OWNER_ADDR $DAPP_OWNER_ADDR $MACHINE_HASH_0x 0x0000000000000000000000000000000000000000000000000000000000000000" > ${TX_RECEIPT}

CARTESI_NODE_ENV_FILE="$MACHINE_HASH_0x.env"
echo "CARTESI_BLOCKCHAIN_FINALITY_OFFSET=1
CARTESI_BLOCKCHAIN_ID=31337
CARTESI_CONTRACTS_INPUT_BOX_ADDRESS=0x59b22D57D4f067708AB0c00552767405926dc768
CARTESI_CONTRACTS_INPUT_BOX_DEPLOYMENT_BLOCK_NUMBER=1
CARTESI_EPOCH_LENGTH=720
CARTESI_AUTH_MNEMONIC=test test test test test test test test test test test junk
CARTESI_BLOCKCHAIN_HTTP_ENDPOINT=http://localhost:8545
CARTESI_BLOCKCHAIN_WS_ENDPOINT=ws://localhost:8546" > ${CARTESI_NODE_ENV_FILE}

# 3) Extract informations from deploy logs
AUTHORITY_FACTORY_ADDR="0xf26a5b278c25d8d41a136d22ad719eaced9c3e63"
HISTORY_FACTORY_ADDR="0x1f158b5320bbf677fda89f9a438df99bbe560a26"
CARTESI_DAPP_FACTORY_ADDR="0x7122cd1221c20892234186facfe8615e6743ab02"

python3 - <<-EOF
	import json
	f = open("${TX_RECEIPT}", "r")
	receipt = json.load(f)
	f.close()
	get_event_by_addr = lambda addr : [event for event in receipt["logs"] if event["address"].lower() == addr][0]
	authority_creation_event = get_event_by_addr("${AUTHORITY_FACTORY_ADDR}")
	dapp_authority_addr = f"0x{authority_creation_event["data"][-40:]}"
	print("DApp Authority address:", dapp_authority_addr)
	history_creation_event = get_event_by_addr("${HISTORY_FACTORY_ADDR}")
	dapp_history_addr = f"0x{history_creation_event["data"][-40:]}"
	print("DApp History address:  ", dapp_history_addr)
	dapp_creation_event = get_event_by_addr("${CARTESI_DAPP_FACTORY_ADDR}")
	dapp_addr = f"0x{dapp_creation_event["data"][-40:]}"
	print("DApp address:          ", dapp_addr)
	node_env_file = open("${CARTESI_NODE_ENV_FILE}", "a")
	print(f"CARTESI_CONTRACTS_APPLICATION_ADDRESS={dapp_addr}", file=node_env_file)
	print(f"CARTESI_CONTRACTS_AUTHORITY_ADDRESS={dapp_authority_addr}", file=node_env_file)
	print(f"CARTESI_CONTRACTS_HISTORY_ADDRESS={dapp_history_addr}", file=node_env_file)
	node_env_file.close()
EOF

echo "CARTESI_POSTGRES_ENDPOINT=" >> ${CARTESI_NODE_ENV_FILE}