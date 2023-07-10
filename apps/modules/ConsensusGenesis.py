"""
    Contains all of the neccessary information and functionality to write the
    consensus config.yaml and genesis.ssz.
"""
import logging

from .ETBConfig import ETBConfig
from .ETBConstants import (
    ForkVersion,
    TerminalBlockHash,
    TerminalBlockHashActivationEpoch,
    MinimalPreset,
)
from .ETBUtils import Eth2TestnetGenesis


class ConsensusGenesisWriter(object):
    def __init__(self, etb_config: ETBConfig, logger: logging.Logger = None):
        self.etb_config: ETBConfig = etb_config
        if logger is None:
            self.logger = logging.getLogger()
        else:
            self.logger = logger

    def _get_old_version_yaml(self):
        # prysm doesn't use proper yaml for parsing.
        preset = self.etb_config.preset_base
        if preset == MinimalPreset:
            preset_name = "minimal"
        else:
            preset_name = "mainnet"

        self.logger.info(f"writing {preset_name} config.yaml")
        return self._get_deneb_devnet_7()
        return f"""
# Extends the {preset_name} preset
PRESET_BASE: '{preset_name}'
CONFIG_NAME: '{self.etb_config.get('config-name')}'

# Genesis
# ---------------------------------------------------------------
# `2**14` (= 16,384)
MIN_GENESIS_ACTIVE_VALIDATOR_COUNT: {self.etb_config.get('min-genesis-active-validator-count')}

# This is an invalid valid and should be updated when you create the genesis
MIN_GENESIS_TIME: {self.etb_config.get_bootstrap_genesis_time()}
GENESIS_FORK_VERSION: 0x{self.etb_config.get("phase0-fork-version"):08x}
GENESIS_DELAY: {self.etb_config.get('consensus-genesis-delay')}


# Forking
# ---------------------------------------------------------------
# Some forks are disabled for now:
#  - These may be re-assigned to another fork-version later
#  - Temporarily set to max uint64 value: 2**64 - 1

# Altair
ALTAIR_FORK_VERSION: 0x{self.etb_config.get("altair-fork-version"):08x}
ALTAIR_FORK_EPOCH: {self.etb_config.get('altair-fork-epoch')}
# Merge
BELLATRIX_FORK_VERSION: 0x{self.etb_config.get("bellatrix-fork-version"):08x}
BELLATRIX_FORK_EPOCH: {self.etb_config.get('bellatrix-fork-epoch')}

# Capella
CAPELLA_FORK_VERSION: 0x{self.etb_config.get("capella-fork-version"):08x}
CAPELLA_FORK_EPOCH: {self.etb_config.get('capella-fork-epoch')}

# EIP4844
EIP4844_FORK_VERSION: 0x{self.etb_config.get("eip4844-fork-version"):08x}
EIP4844_FORK_EPOCH: {self.etb_config.get('eip4844-fork-epoch')}


TERMINAL_TOTAL_DIFFICULTY: {self.etb_config.get('terminal-total-difficulty')}
TERMINAL_BLOCK_HASH: {TerminalBlockHash}
TERMINAL_BLOCK_HASH_ACTIVATION_EPOCH: {TerminalBlockHashActivationEpoch}


# Time parameters
# ---------------------------------------------------------------
SECONDS_PER_SLOT: {self.etb_config.get_preset_value('seconds-per-slot')}
SECONDS_PER_ETH1_BLOCK: {self.etb_config.get_preset_value('seconds-per-eth1-block')}
MIN_VALIDATOR_WITHDRAWABILITY_DELAY: {self.etb_config.get_preset_value('min-validator-withdrawability-delay')}
SHARD_COMMITTEE_PERIOD: {self.etb_config.get_preset_value('shard-committee-period')}
ETH1_FOLLOW_DISTANCE: {self.etb_config.get_preset_value('eth1-follow-distance')}


# Validator cycle
# ---------------------------------------------------------------
INACTIVITY_SCORE_BIAS: {self.etb_config.get_preset_value('inactivity-score-bias')}
INACTIVITY_SCORE_RECOVERY_RATE: {self.etb_config.get_preset_value('inactivity-score-recovery-rate')}
EJECTION_BALANCE: {self.etb_config.get_preset_value('ejection-balance')}
MIN_PER_EPOCH_CHURN_LIMIT: {self.etb_config.get_preset_value('min-per-epoch-churn-limit')}
CHURN_LIMIT_QUOTIENT: {self.etb_config.get_preset_value('churn-limit-quotient')}

# Fork choice
# ---------------------------------------------------------------
# 40%
PROPOSER_SCORE_BOOST: 40

# Deposit contract
# ---------------------------------------------------------------
DEPOSIT_CHAIN_ID: {self.etb_config.get('chain-id')}
DEPOSIT_NETWORK_ID: {self.etb_config.get('network-id')}
DEPOSIT_CONTRACT_ADDRESS: {self.etb_config.config_params.get('deposit-contract-address')}

# Networking
# ---------------------------------------------------------------
# `10 * 2**20` (= 10485760, 10 MiB)
GOSSIP_MAX_SIZE: 10485760
MAX_CHUNK_SIZE: 10485760
MAX_REQUEST_BLOCKS: 1024

EPOCHS_PER_SUBNET_SUBSCRIPTION: 256
# `MIN_VALIDATOR_WITHDRAWABILITY_DELAY + CHURN_LIMIT_QUOTIENT // 2` (= 33024, ~5 months)
MIN_EPOCHS_FOR_BLOCK_REQUESTS: 33024

TTFB_TIMEOUT: 5
# 10s
RESP_TIMEOUT: 10
ATTESTATION_PROPAGATION_SLOT_RANGE: 32
# 500ms
MAXIMUM_GOSSIP_CLOCK_DISPARITY: 500
MESSAGE_DOMAIN_INVALID_SNAPPY: 0x00000000
MESSAGE_DOMAIN_VALID_SNAPPY: 0x01000000
# 2 subnets per node
SUBNETS_PER_NODE: 2
# 2**8 (= 64)
ATTESTATION_SUBNET_COUNT: 64
ATTESTATION_SUBNET_EXTRA_BITS: 0
# ceillog2(ATTESTATION_SUBNET_COUNT) + ATTESTATION_SUBNET_EXTRA_BITS
ATTESTATION_SUBNET_PREFIX_BITS: 6
"""

    def _get_deneb_devnet_7(self):
        return f"""
# Extends the mainnet preset
PRESET_BASE: 'mainnet'
CONFIG_NAME: '{self.etb_config.get('config-name')}'

# Genesis
# ---------------------------------------------------------------
# `2**14` (= 16,384)
MIN_GENESIS_ACTIVE_VALIDATOR_COUNT: {self.etb_config.get('min-genesis-active-validator-count')}
# Mar-01-2021 08:53:32 AM +UTC
# This is an invalid valid and should be updated when you create the genesis
MIN_GENESIS_TIME: {self.etb_config.get_bootstrap_genesis_time()}
GENESIS_FORK_VERSION: 0x{self.etb_config.get("phase0-fork-version"):08x}
GENESIS_DELAY: {self.etb_config.get('consensus-genesis-delay')}


# Forking
# ---------------------------------------------------------------
# Some forks are disabled for now:
#  - These may be re-assigned to another fork-version later
#  - Temporarily set to max uint64 value: 2**64 - 1

# Altair
ALTAIR_FORK_VERSION: 0x{self.etb_config.get("altair-fork-version"):08x}
ALTAIR_FORK_EPOCH: {self.etb_config.get('altair-fork-epoch')}
# Merge
BELLATRIX_FORK_VERSION: 0x{self.etb_config.get("bellatrix-fork-version"):08x}
BELLATRIX_FORK_EPOCH: {self.etb_config.get('bellatrix-fork-epoch')}

# Capella
CAPELLA_FORK_VERSION: 0x{self.etb_config.get("capella-fork-version"):08x}
CAPELLA_FORK_EPOCH: {self.etb_config.get('capella-fork-epoch')}

# # DENEB
# DENEB_FORK_VERSION: 0x50714639
# DENEB_FORK_EPOCH: 10

TERMINAL_TOTAL_DIFFICULTY: {self.etb_config.get('terminal-total-difficulty')}
TERMINAL_BLOCK_HASH: {TerminalBlockHash}
TERMINAL_BLOCK_HASH_ACTIVATION_EPOCH: {TerminalBlockHashActivationEpoch}

# Time parameters
# ---------------------------------------------------------------
# 12 seconds
SECONDS_PER_SLOT: 12
# 14 (estimate from Eth1 mainnet)
SECONDS_PER_ETH1_BLOCK: 12
# 2**0 (= 1) epochs ~1 hours
MIN_VALIDATOR_WITHDRAWABILITY_DELAY: 1
# 2**8 (= 256) epochs ~27 hours
SHARD_COMMITTEE_PERIOD: 1
# 2**11 (= 2,048) Eth1 blocks ~8 hours
ETH1_FOLLOW_DISTANCE: 12


# Validator cycle
# ---------------------------------------------------------------
# 2**2 (= 4)
INACTIVITY_SCORE_BIAS: 4
# 2**4 (= 16)
INACTIVITY_SCORE_RECOVERY_RATE: 16
# 2**4 * 10**9 (= 16,000,000,000) Gwei
EJECTION_BALANCE: 31000000000
# 2**2 (= 4)
MIN_PER_EPOCH_CHURN_LIMIT: 4
# 2**16 (= 65,536)
CHURN_LIMIT_QUOTIENT: 65536

# Fork choice
# ---------------------------------------------------------------
# 40%
PROPOSER_SCORE_BOOST: 40

# Deposit contract
# ---------------------------------------------------------------
DEPOSIT_CHAIN_ID: {self.etb_config.get('chain-id')}
DEPOSIT_NETWORK_ID: {self.etb_config.get('network-id')}
DEPOSIT_CONTRACT_ADDRESS: {self.etb_config.config_params.get('deposit-contract-address')}

# Networking
# ---------------------------------------------------------------
# `10 * 2**20` (= 10485760, 10 MiB)
GOSSIP_MAX_SIZE: 10485760
# `2**10` (= 1024)
MAX_REQUEST_BLOCKS: 1024
# `2**8` (= 256)
EPOCHS_PER_SUBNET_SUBSCRIPTION: 256
# `MIN_VALIDATOR_WITHDRAWABILITY_DELAY + CHURN_LIMIT_QUOTIENT // 2` (= 33024, ~5 months)
MIN_EPOCHS_FOR_BLOCK_REQUESTS: 33024
# `10 * 2**20` (=10485760, 10 MiB)
MAX_CHUNK_SIZE: 10485760
# 5s
TTFB_TIMEOUT: 5
# 10s
RESP_TIMEOUT: 10
ATTESTATION_PROPAGATION_SLOT_RANGE: 32
# 500ms
MAXIMUM_GOSSIP_CLOCK_DISPARITY: 500
MESSAGE_DOMAIN_INVALID_SNAPPY: 0x00000000
MESSAGE_DOMAIN_VALID_SNAPPY: 0x01000000
# 2 subnets per node
SUBNETS_PER_NODE: 2
# 2**8 (= 64)
ATTESTATION_SUBNET_COUNT: 64
ATTESTATION_SUBNET_EXTRA_BITS: 0
# ceillog2(ATTESTATION_SUBNET_COUNT) + ATTESTATION_SUBNET_EXTRA_BITS
ATTESTATION_SUBNET_PREFIX_BITS: 6

# Deneb
# `2**7` (=128)
MAX_REQUEST_BLOCKS_DENEB: 128
# MAX_REQUEST_BLOCKS_DENEB * MAX_BLOBS_PER_BLOCK
MAX_REQUEST_BLOB_SIDECARS: 768
# `2**12` (= 4096 epochs, ~18 days)
MIN_EPOCHS_FOR_BLOB_SIDECARS_REQUESTS: 4096
# `6`
BLOB_SIDECAR_SUBNET_COUNT: 6
# `uint64(6)`
MAX_BLOBS_PER_BLOCK: 6
"""

    def create_consensus_genesis_ssz(self):
        e2tg = Eth2TestnetGenesis(self.etb_config)
        return e2tg.write_genesis_ssz()

    def create_consensus_config_yaml(self):
        return self._get_old_version_yaml()
