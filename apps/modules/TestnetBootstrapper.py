"""
    This module is the glue to tie together all the execution and consensus client bootstrapping
    phases. There is a high level doc in docs that discusses this process.
"""
import json
import logging
import os
import pathlib
import random
import re
import shutil
import subprocess
import time
from pathlib import Path
from typing import Dict

from ruamel.yaml import YAML

from .ConsensusGenesis import ConsensusGenesisWriter
from .ETBConfig import ETBConfig, ClientInstance
from .ETBUtils import write_checkpoint_file, Eth2ValTools
from .ETBConstants import ForkVersion
from .ExecutionGenesis import ExecutionGenesisWriter
from .ClientRequest import (
    eth_getBlockByNumber,
    admin_nodeInfo,
    perform_batched_request,
    admin_addPeer,
)


class EthereumTestnetBootstrapper(object):
    """
    The Testnet Bootstrapper wraps all the consensus and execution
    bootstrapper logic to bootstrap all the clients. It also handles
    the consensus bootnode.

    The EthereumTestnetBootstrapper is used to init the testnet and later is
    used to bootstrap and run the testnet.
    """

    def __init__(self, config_path, logger: logging.Logger = None):
        if logger is None:
            # grab a logger from name
            self.logger = logging.getLogger(__name__)
            self.logger.warning(
                "Default logger initialized since one was not supplied."
            )
        self.logger = logger
        self.etb_config = ETBConfig(config_path, self.logger)
        self.config_path = config_path  # save this to copy it into testnet dir.

    def init_testnet(self):
        """
        The init routine simply processes the etb-config file and performs all
        the work that can be done statically. This includes creating the dir
        structure for the testnet and populating the cl bootnode enr file.
        """
        # create the testnet root
        Path(self.etb_config.get("testnet-dir")).mkdir()

        # create dirs
        self._create_client_testnet_directories()

        # create other static files
        self._create_consensus_bootnode_dir()  # where we write the bootnode enr for CLs
        self._write_client_jwt_secrets()

        # self.etb_config.write_to_docker_compose()
        self.logger.debug("writing docker compose")
        with open(self.etb_config.get("docker-compose-file"), "w") as f:
            yaml=YAML(typ='safe')
            yaml.dump(self.etb_config.get_docker_compose_repr(), f)

        # copy in the config file we used for the init process.
        shutil.copy(self.config_path, self.etb_config.get("etb-config-file"))

    def bootstrap_testnet(self):
        """
        This routine bootstraps the testnet. The general process is as follows:
        1. open the etb_config file and write the current time.
        2. signal the consensus bootnode to come online.
        3. create the execution genesis files and then signal those clients to
           come online.
        4. pair all the el clients.
        5. create the consensus genesis files and then signal those clients to
            come online

        """
        # set the bootstrap time and update the file. Then signal dockers via
        # checkpoint.
        self.etb_config.set_bootstrap_genesis_time(int(time.time()))

        # signal the consensus bootnode is ready to come online.
        write_checkpoint_file(self.etb_config.get("consensus-bootnode-checkpoint-file"))

        # bootstrap all the execution clients.
        self._write_execution_genesis_files()
        write_checkpoint_file(self.etb_config.get("execution-checkpoint-file"))

        # pair all the EL clients together.
        # antithesis: add retry logic and terminate message on failure
        pair_el_clients_attempts = 10
        for attempt in range(pair_el_clients_attempts):
            try:
                print(f"Attempt {attempt + 1}/{pair_el_clients_attempts}", flush=True)
                self.pair_el_clients()
                print("Successfully paired EL clients", flush=True)
                break
            except Exception as e:
                if attempt == (pair_el_clients_attempts - 1):
                    print("Failed to pair EL clients so terminating experiment", flush=True)
                    print("terminate", flush=True)
                    raise e
                else:
                    sleep_s = 2 ** (attempt + 1)
                    print(f"Failed to pair EL clients. Sleeping {sleep_s} seconds", flush=True)
                    time.sleep(sleep_s)

        # if needed we start the clique miners
        if self.etb_config.get_genesis_fork_upgrade() < ForkVersion.Bellatrix:
            # TODO figure out a more elegant way.
            self._start_clique_miners()

        self.etb_config.write_etb_config_to_testnet_dir()
        write_checkpoint_file(self.etb_config.get("etb-config-checkpoint-file"))

        # nimbus requires a contract_deposit_block_hash so fetch it.
        self.write_contract_deployment_block_files()

        # bootstrap all the consensus clients.
        self.write_consensus_genesis_files()
        # cl_bootstrapper.bootstrap_consensus_clients()
        write_checkpoint_file(self.etb_config.get("consensus-checkpoint-file"))

    def clear_last_run(self):
        """
        Clear all the files and dirs present in the testnet-root.
        """
        testnet_root = pathlib.Path(self.etb_config.get("testnet-root"))
        docker_compose_file = pathlib.Path(self.etb_config.get("docker-compose-file"))
        if testnet_root.exists():
            for root, dirs, files in os.walk(testnet_root):
                for f in files:
                    pathlib.Path(f"{root}/{f}").unlink()
                for d in dirs:
                    shutil.rmtree(f"{root}/{d}")

        if docker_compose_file.exists():
            docker_compose_file.unlink()

    def _start_clique_miners(self) -> None:
        """
        When using clique (pre-merge) we must unlock the signing account
        on one of the EL clients and begin mining. By default, we only use
        one signer, and that signer is the key used in the first premine.

        The instance that starts mining is the first entry of the first client
        that implements the api. By default, we use alphabetical order.
        :return: None
        """
        raise Exception("NOT IMPLEMENTED")
        # This is the previous implementation it has not been converted..from the old code.
        # possible_el_clients = self.etb_config.get_execution_rpc_paths(protocol='http',
        #                                                               apis=['personal', 'miner', 'clique'])
        # if len(possible_el_clients) == 0:
        #     raise Exception("Error: Couldn't start clique miners as no EL client implements personal and miner")
        # self.logger.debug(f"Found possible clique miners: {possible_el_clients}")
        # names = list(possible_el_clients.keys())
        # names.sort()
        #
        # miner_name = names[0]
        # self.logger.info(f"Starting clique miner for: {miner_name} : {possible_el_clients[miner_name]}")
        #
        # address = self.etb_config.get_clique_signer()
        # passphrase = self.etb_config.get('eth1-passphrase')
        #
        # unlock_rpc = personal_unlock_account_RPC(address=address, passphrase=passphrase, duration=100000)
        # miner_rpc = miner_start_RPC(1)
        #
        # etb_rpc = ETBExecutionRPC(self.etb_config, timeout=5)
        # etb_rpc.do_rpc_request(unlock_rpc, client_nodes=[miner_name], all_clients=False)
        # etb_rpc.do_rpc_request(miner_rpc, client_nodes=[miner_name], all_clients=False)

    def _create_consensus_bootnode_dir(self):
        """
        Populate the enr file to be used by the consensus bootnode.
        """
        # handle the consensus bootnode enr files:
        enr_path = Path(self.etb_config.get("consensus-bootnode-file"))
        enr_path.parents[0].mkdir(exist_ok=True)

    def pair_el_clients(self):
        """
        Given a dict of enodes, iterate through it and pair the clients via
        the admin RPC interface.
        """
        admin_api_filter = re.compile(r"(admin|ADMIN)")
        clients = self.etb_config.get_client_instances(el_api_filter=admin_api_filter)
        rpc_request = admin_nodeInfo(
            self.logger, timeout=30
        )  # some els are slow to come up.

        enodes = {}
        for client, resp in perform_batched_request(rpc_request, clients):
            error, result = resp
            if error is None:
                enodes[client] = rpc_request.retrieve_response(result)["enode"]
            else:
                self.logger.error(
                    f"Failed to get enode from client: {client.name}. Exception: {error}"
                )
                raise error

        # now peer the clients with themselves.
        for client, enode in enodes.items():
            add_enode_rpc_request = admin_addPeer(enode, self.logger)
            for c in clients:
                if c.name != client.name:
                    err, result = add_enode_rpc_request.perform_request(client)
                    if not err is None:
                        self.logger.error(f"admin_addPeer failed with {err}")

    def get_contract_deployment_block(self) -> tuple[str, int]:
        """
            Fetch a random EL client that implements the eth http api and get
            the 0th block for the contract deployment.
        :return: (block_number, block_hash)
        """
        el_http_regex = re.compile(r"(eth|ETH)")
        possible_clients = self.etb_config.get_client_instances(
            el_api_filter=el_http_regex
        )
        if not len(possible_clients) > 0:
            raise Exception("No clients have an EL that supports the eth http-api")

        client = random.choice(possible_clients)
        rpc = eth_getBlockByNumber("0x0", self.logger)
        err, response = rpc.perform_request(client)
        if err is None:
            block = rpc.retrieve_response(response)
            block_number = block["number"]
            block_hash = block["hash"]
            self.logger.debug(f"Got block {block_number} with hash: {block_hash}")
            return block_hash, int(block_number, 16)
        else:
            self.logger.error(
                f"failed to get the contract deployment block with: {err}"
            )
            raise err

    def write_contract_deployment_block_files(self):
        """
        Nimbus requires this to start up.
        :return: None
        """
        block_hash, block_number = self.get_contract_deployment_block()
        with open(
                self.etb_config.get("deposit-contract-deployment-block-hash-file"), "w"
        ) as f:
            f.write(block_hash)
        with open(
                self.etb_config.get("deposit-contract-deployment-block-number-file"), "w"
        ) as f:
            f.write(str(block_number))

    def _create_client_testnet_directories(self):
        """
        Create the testnet directory structure of the testnet for init purposes

        iterate through the etb clients and create their required dirs.
        The dir structure for a client is:
            /{testnet_dir}/node_{node_num}/{execution-client}
        """
        self.logger.info("Creating client testnet dirs.")
        for cic in self.etb_config.client_instance_collections.values():
            root_dir = pathlib.Path(cic.get_root_client_testnet_dir())
            root_dir.mkdir()
            self.logger.debug(f"created root-dir: {root_dir}")
            for client_instance in cic:
                node_dir = pathlib.Path(client_instance.get_consensus_node_dir())
                el_dir = pathlib.Path(client_instance.get_execution_node_dir())
                node_dir.mkdir()
                self.logger.debug(f"created node-dir: {node_dir}")
                el_dir.mkdir()
                self.logger.debug(f"created el-dir: {el_dir}")

    def _write_client_jwt_secrets(self):
        self.logger.info("Creating client jwt-secrets")
        for client_instance in self.etb_config.get_client_instances():
            jwt_secret_file = client_instance.get_jwt_secret_file()
            self.logger.debug(f"populating jwt-secret-file: {jwt_secret_file}")
            with open(jwt_secret_file, "w") as f:
                f.write(f"0x{random.randbytes(32).hex()}")

    def _write_execution_genesis_files(self) -> None:
        """
        Writes all the execution genesis json files for EL clients to the
        file paths specified in the etb-config.
        """

        egw = ExecutionGenesisWriter(self.etb_config)

        # TODO: see that hacky workaround post in ETBConfig::get()
        # if not self.etb_config.has("bootstrap-genesis"):
        #     raise Exception("Cannot write execution genesis files before bootstrapping.")

        with open(self.etb_config.get("geth-genesis-file"), "w") as f:
            f.write(json.dumps(egw.create_geth_genesis()))

        with open(self.etb_config.get("besu-genesis-file"), "w") as f:
            f.write(json.dumps(egw.create_besu_genesis()))

        with open(self.etb_config.get("nether-mind-genesis-file"), "w") as f:
            f.write(json.dumps(egw.create_nethermind_genesis()))

    def write_consensus_genesis_files(self):
        """
        Create the consensus config.yaml file and the genesis.ssz file.
        """
        self.logger.info("ConsensusBootstrapper bootstrapping consensus..")
        cgw = ConsensusGenesisWriter(self.etb_config)
        with open(self.etb_config.get("consensus-config-file"), "w") as f:
            f.write(cgw.create_consensus_config_yaml())
        self.logger.debug("ConsensusBootstrapper wrote config.yaml")
        with open(self.etb_config.get("consensus-genesis-file"), "wb") as f:
            f.write(cgw.create_consensus_genesis_ssz())
        self.logger.debug("ConsensusBootstrapper wrote genesis.ssz")
        # we have everything we need to populate all the consensus directories

        cdg = ConsensusDirectoryGeneratorV2(self.etb_config, self.logger)
        cdg.generate_validator_stores()
        with open("/data/validators-to-client-mapping", "w") as f:
            f.write(cdg.stringify_validators_to_client_mapping())
        self.logger.debug("ConsensusBootstrapper wrote validators-to-client-mapping")




class ConsensusDirectoryGeneratorV2(object):
    """
    Generates the consensus directories for all clients includeing the validator keystores.
    """

    def __init__(self, etb_config: ETBConfig, logger: logging.Logger = None):
        if logger is None:
            self.logger = logging.getLogger(__name__)
        else:
            self.logger = logger

        self.etb_config: ETBConfig = etb_config
        self.genesis_ssz_file = self.etb_config.get("consensus-genesis-file")
        self.consensus_config = self.etb_config.get("consensus-config-file")

        self.eth2valtools = Eth2ValTools(self.logger)
        self.validators_to_client_mapping = []

    def stringify_validators_to_client_mapping(self) -> str:
        return '\n'.join(self.validators_to_client_mapping)

    def generate_validator_stores(self):
        # create the validator keystores.
        for client in self.etb_config.get_client_instances():
            consensus_client_name = client.consensus_config.get("client")
            keystore_dir = client.get_consensus_node_dir() + "/generated_keystores/"
            num_validators = client.consensus_config.get("num-validators")
            min_ndx = client.get("validator-offset-start")
            max_ndx = min_ndx + num_validators
            src_mnemonic = self.etb_config.accounts.get("validator-mnemonic")
            print(
                f"generating {num_validators} validator stores for client: {consensus_client_name}",
                flush=True,
            )

            self.eth2valtools.generate_keystores(
                keystore_dir,
                min_ndx,
                max_ndx,
                src_mnemonic,
                prysm=consensus_client_name == "prysm",
                prysm_password=client.get("validator-password"),
            )

            if client.root_name == "teku-whale":
                self.validators_to_client_mapping.append(f"{min_ndx}-{max_ndx-10} {client.root_name}")
            else:
                self.validators_to_client_mapping.append(f"{min_ndx}-{max_ndx} {client.root_name}")

            # get the correct key representation
            if consensus_client_name == "teku":
                shutil.copytree(
                    keystore_dir + "/teku-keys",
                    client.get_consensus_node_dir() + "/keys",
                )
                shutil.copytree(
                    keystore_dir + "/teku-secrets",
                    client.get_consensus_node_dir() + "/secrets",
                )
            elif consensus_client_name == "prysm":
                for item in pathlib.Path(keystore_dir).glob("prysm/*"):
                    if item.is_dir():
                        shutil.copytree(
                            item, f"{client.get_consensus_node_dir()}/{item.name}"
                        )
                    else:
                        shutil.copy(
                            item, f"{client.get_consensus_node_dir()}/{item.name}"
                        )
                # prysm requires a wallet-password.txt to launch.
                with open(client.get_wallet_password_path(), "w") as f:
                    f.write(client.get_validator_password())
            elif consensus_client_name == "lighthouse":
                shutil.copytree(
                    keystore_dir + "/keys", client.get_consensus_node_dir() + "/keys"
                )
                shutil.copytree(
                    keystore_dir + "/secrets",
                    client.get_consensus_node_dir() + "/secrets",
                )
                # put lighthouse specific items in the dir
                lighthouse_deploy_block = pathlib.Path(
                    client.get_testnet_dir() + "/deploy_block.txt"
                )
                if not lighthouse_deploy_block.exists():
                    print("moving lighthouse deploy block to dir", flush=True)
                    shutil.copy(
                        src=self.etb_config.files.get(
                            "deposit-contract-deployment-block-number-file"
                        ),
                        dst=str(lighthouse_deploy_block),
                    )
            elif consensus_client_name == "nimbus":
                shutil.copytree(
                    keystore_dir + "/nimbus-keys",
                    client.get_consensus_node_dir() + "/keys",
                )
                shutil.copytree(
                    keystore_dir + "/secrets",
                    client.get_consensus_node_dir() + "/secrets",
                )
                # put nimbus specific items in the dir.
                nimbus_deployment_block_hash_path = pathlib.Path(
                    client.get_testnet_dir() + "/deposit_contract_block_hash.txt"
                )
                nimbus_deployment_block_number = pathlib.Path(
                    client.get_testnet_dir() + "/deposit_contract_block.txt"
                )
                if not nimbus_deployment_block_hash_path.exists():
                    shutil.copy(
                        src=self.etb_config.files.get(
                            "deposit-contract-deployment-block-hash-file"
                        ),
                        dst=str(nimbus_deployment_block_hash_path),
                    )
                if not nimbus_deployment_block_number.exists():
                    print("moving nimbus files over", flush=True)
                    shutil.copy(
                        src=self.etb_config.files.get(
                            "deposit-contract-deployment-block-number-file"
                        ),
                        dst=str(nimbus_deployment_block_number),
                    )
            elif consensus_client_name == "lodestar":
                shutil.copytree(
                    keystore_dir + "/keys", client.get_consensus_node_dir() + "/keys"
                )
                shutil.copytree(
                    keystore_dir + "/lodestar-secrets",
                    client.get_consensus_node_dir() + "/secrets",
                )
                # lodestar specific items
                pathlib.Path(client.get_consensus_node_dir() + "/validatordb").mkdir()
            else:
                raise Exception(f"Unknown consensus clients: {client.name}")

            shutil.copy(
                self.etb_config.get("consensus-genesis-file"),
                client.get_testnet_dir() + "/genesis.ssz",
            )
            shutil.copy(
                self.etb_config.get("consensus-config-file"),
                client.get_testnet_dir() + "/config.yaml",
            )
            shutil.rmtree(keystore_dir)
