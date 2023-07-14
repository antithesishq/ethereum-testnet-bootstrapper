### Provides a method of gettting a high level overview of the running
### experiment to check on the health of the network.
###
### Status checking is done in 3 phases.
###
### Phase0:
###     allow the network to come up, confirm that things are behaving properly.
###     if there has been an issue print termination message.
###
### Phase1:
### 	  Phase 1 starts is the starting point for experimentation/chaos.
###
### Phase2:
###     This is the endpoint for chaos. There may be some issues but we wait
###     until phase3 for to test for failures.
###
### Phase3:
###     Phase3 marks the point where the network should of healed. All issues
###     at this point should be considered errors.
import logging
import time
import json
from json import JSONEncoder
from json.decoder import JSONDecodeError
from pathlib import Path

import requests

from etb.monitoring.testnet_monitor import (
    TestnetMonitor,
    TestnetMonitorAction,
    TestnetMonitorActionInterval,
)

from etb.interfaces.client_request import (
    perform_batched_request,
    BeaconAPIgetBlockV2,
    BeaconAPIgetBlockV1,
    BeaconAPIgetValidators,
)

from typing import Union, Any

# from modules.ClientRequest import perform_batched_request, beacon_getBlockV2, beacon_getValidators, beacon_getBlockV1

# from modules.BeaconAPI import BeaconAPI, ETBConsensusBeaconAPI
from etb.config.etb_config import ETBConfig, ClientInstance

# from modules.TestnetHealthMetrics import UniqueConsensusHeads
from multiprocessing import Pool

from typing import Optional


###
###
###
class VarsEncoder(JSONEncoder):
    def default(self, o):
        return vars(o)

encoder = VarsEncoder()

class Head:
    def __init__(self, slot: str, state_root: str, graffiti: str):
        self.slot = slot
        self.state_root = state_root
        self.graffiti = graffiti
        self.nodes = []
    def add_node(self, node: str):
        self.nodes.append(node)

class HeadStatusCheck:
    def __init__(self, unreachable_clients: list[str] = [], heads: list[Head] = []):
        self.unreachable_clients = unreachable_clients
        self.heads = heads

    def add_unreachable(self, node):
        self.unreachable_clients.append(node)

    def add_head(self, head):
        self.heads.append(head)

    def __str__(self) -> str:
        num_forks = len(self.heads) - 1
        if len(self.unreachable_clients) > 0:
            num_forks += 1

        out = f"found {num_forks} forks: "
        for h in self.heads:
            out += f"{h.slot}:{h.state_root}:{h.graffiti}   {', '.join(h.nodes)}\n"

        if len(self.unreachable_clients) > 0:
            out += f"unreachable hosts: {', '.join(self.unreachable_clients)}\n"
        return out

def get_heads_status_check_slot(clients_to_monitor: list[ClientInstance]) -> HeadStatusCheck:
    """
    Returns the strings to print per slot and a boolean if there is a fork. Note
    this isn't accurate because one client could be behind or we could be
    slightly skewed.
    :param clients_to_monitor:
    :param clients:
    :return: health_network (bool) : out str
    """
    unreachable_clients = []
    heads: dict[str, Head] = {}

    # rpc_request = beacon_getBlockV2()
    rpc_request = BeaconAPIgetBlockV2(max_retries=5, timeout=3)
    for cl_client, rpc_future in perform_batched_request(rpc_request, clients_to_monitor).items():
        result: Union[requests.Response, Exception] = rpc_future.result()
        if rpc_request.is_valid(result):
            block = rpc_request.get_block(result)
            state_root = str(block["state_root"])
            if state_root not in heads:
                head = Head(
                    block["slot"],
                    state_root,
                    bytes.fromhex(block["body"]["graffiti"][2:])
                    .decode("utf-8")
                    .replace("\x00", ""))
                heads[state_root] = head
            heads[state_root].add_node(cl_client.name)
            # antithesis: have seen instances of invalid json
            # except JSONDecodeError as e:
            #     print(f"Invalid JSON received from client {cl_client.name}'s getBlockV2 beacon API: {response.content}", flush=True)
            #     unreachable_clients.append(cl_client.name)
        else:
            unreachable_clients.append(cl_client.name)
    return HeadStatusCheck(unreachable_clients, [h for h in heads.values()])

def check_for_consensus(
    clients_to_monitor: list[ClientInstance], max_retries=3
) -> bool:
    """
        This is the same as the per slot check except we will try multiple times
        to try and find consensus.
    :param clients_to_monitor:
    :return:
    """

    found_consensus = False
    curr_try = 0
    # antithesis: change while condition
    while (not found_consensus) and (curr_try <= max_retries):
        # antithesis: add print
        print(f"Checking for consensus, attempt {curr_try + 1} out of {max_retries}", flush=True)
        if curr_try > 0:
            sleep_s = 2 ** (curr_try + 1)
            print(f"Sleeping for {sleep_s} seconds before checking for consensus.", flush=True)
            time.sleep(sleep_s)
        curr_try += 1
        status = get_heads_status_check_slot(clients_to_monitor)
        print(encoder.encode(status), flush=True)
        if len(status.unreachable_clients) == 0 and len(status.heads) == 1:
            found_consensus = True
            break

    return found_consensus


# Example beacon_validators response:
# {
#   "execution_optimistic": false,
#   "finalized": false,
#   "data": [
#     {
#       "index": "1",
#       "balance": "1",
#       "status": "active_ongoing",
#       "validator": {
#         "pubkey": "0x93247f2209abcacf57b75a51dafae777f9dd38bc7053d1af526f220a7489a6d3a2753e5f3e8b1cfe39b56f43611df74a",
#         "withdrawal_credentials": "0xcf8e0d4e9587369b2301d0790347320302cc0943d5a1884560367e8208d920f2",
#         "effective_balance": "1",
#         "slashed": false,
#         "activation_eligibility_epoch": "1",
#         "activation_epoch": "1",
#         "exit_epoch": "1",
#         "withdrawable_epoch": "1"
#       }
#     }
#   ]
# }

def get_all_slots_per_client(client):
    p = "head"
    parents_and_slots = []
    # We are not checking for forks in teku
    # This is a temporary if statement to avoid querying for teku, their api is super slow and will extend the rollout unnecessarily
    if "teku" in client.root_name :
        return []
    try:
        while (True):
            b = BeaconAPIgetBlockV1(max_retries= 2, timeout=15)
            response = b.perform_request(client)
            data = b.get_block(response)
            # print(data)
            p = data['parent_root']
            s = data['slot']
            print(f"{client.root_name}: {[p, s]}")
            parents_and_slots.append([p, s])
            if (p == '0x0000000000000000000000000000000000000000000000000000000000000000'):
                # print("End of block has been reached")
                break
    except Exception as e:
        print(e)
        # It could be possible that we retrieve a response for one slot but not the next slot because of connection issues, this might produce an incomplete chain, therefore we just return the empty chain. No point requering after 15 seconds
        return []
    return [client.root_name, parents_and_slots]

def calculate_slots_skipped_by_all_clients(clients_and_data, highest_slot):
    clients_to_skipped_slots = {}
    for [client, data] in clients_and_data:
        slots = [slot for [_parent, slot] in data]
        skipped_slots = [num for num in range(1, int(highest_slot)) if str(num) not in slots]
        clients_to_skipped_slots[client] =  skipped_slots
    return clients_to_skipped_slots

def group_together_clients_with_similar_slots_or_chains(clients_and_data_str, mode="chain"):
    def seen_before(key, seen):
        if (key in seen):
            seen[key].append(client)
        else:
            seen[key] = [client]
        return seen
    seen = {}
    for [client, [parents_str, slots_str]] in clients_and_data_str:
        if mode == "chain":
            seen_before(parents_str, seen)
        elif mode == "slot":
            seen_before(slots_str, seen)
    return seen

def rehash_parent_hash(clients_and_data): # returns the clients_and_data with rehashed parents and the hash map for rehashing
    count = 1
    new_hash = {}
    clients_and_data_rehashed = []
    for [client, data] in clients_and_data:
        data_rehashed = []
        for [parent, slot] in data:
            parents_rehashed = []
            if parent not in new_hash:
                new_hash[parent] = count
                count += 1
            data_rehashed.append([new_hash[parent], slot])
        clients_and_data_rehashed.append([client, data_rehashed])
    return [clients_and_data_rehashed, new_hash]

def stringify_data(clients_and_data):
    clients_and_data_str = []
    for [client, data] in clients_and_data:
        parents_str = ''
        slots_str = ''
        for [parent, slot] in data:
            parents_str += f' {parent}'
            slots_str += f' {slot}'
        parents_str += " "
        slots_str += " "
        clients_and_data_str.append([client, [parents_str, slots_str]])
    return clients_and_data_str

def calculate_highest_slot_across_all_chains(clients_and_data):
    highest = 0
    for [_client, data] in clients_and_data:
        for [_parent, slot] in data:
            if int(highest) < int(slot):
                highest = slot
    return highest

def get_all_slots(clients):
    clients_and_data = []
    with Pool(5) as p:
        clients_and_data = p.map(get_all_slots_per_client, clients)
    return list(filter(lambda client_and_data: client_and_data != [], clients_and_data))

def calculate_real_forks_and_unsynced_children(str_parents_to_clients):
    parents_chains = list(str_parents_to_clients.keys())
    parents_chains_sorted = sorted(parents_chains, key=lambda x: len(x))
    real_forks = {}
    parents = []
    for c1 in parents_chains_sorted:
        c1_is_parent = True
        for c2 in parents_chains_sorted:
            start = c1.find(" ")
            end = c1.find(" ", start + 1) + 1
            # We can't use this to separate the skipped slots because we can't assume one chain of skipped slots is the child of another based on one skipped slot.
            if c1 != c2 and c1 != "" and c2 != "" and c1[start:end] in c2: # if we add `and c1[start:end] != ""` then we will consider chains with nothing in them a definite fork
                c1_is_parent = False
                if c1 in real_forks:
                    real_forks[c2] = {c1: real_forks[c1]}
                else:
                    real_forks[c2] = c1
        if c1_is_parent:
            parents.append(c1)
    
    unsynced_chains_tree = {}
    for p in parents:
        if p in real_forks:
            unsynced_chains_tree[p] = real_forks[p]
        else:
            unsynced_chains_tree[p] = ""
    return unsynced_chains_tree


def print_real_chains_and_unsynced_children(str_parents_to_clients, unsynced_chains_tree, clients_to_skipped_slots):
    def recursive_print(chain_tree, level):
        if chain_tree == "":
            return 0
        if isinstance(chain_tree, str):
            start = chain_tree.find(" ")
            end = chain_tree.find(" ", start + 1) + 1
            print(f"SYNCING {level} latest parent hash: {chain_tree[start:end]} {str_parents_to_clients[chain_tree]}")
            return 0
        for chain in chain_tree.keys():
            start = chain.find(" ")
            end = chain.find(" ", start + 1) + 1
            print(f"SYNCING {level} latest parent hash: {chain[start:end]} {str_parents_to_clients[chain]}")
            return recursive_print(chain_tree[chain], level + "--")
    for chain in unsynced_chains_tree.keys():
        print(f"UNIQUE CHAIN {str_parents_to_clients[chain]} {chain}")
        print(f"SKIPPED SLOTS {clients_to_skipped_slots[str_parents_to_clients[chain][0]]}")
        recursive_print(unsynced_chains_tree[chain], "--------")

def print_all_data_for_every_client(clients):
    # logger = logging.getLogger()
    # etb = ETBConfig("/data/etb-config.yaml", logger)
    # clients = etb.get_client_instances()
    clients_and_data = get_all_slots(clients)
    if clients_and_data == []:
        print("FAIL: No data retrieved")
    highest_slot = calculate_highest_slot_across_all_chains(clients_and_data)
    clients_to_skipped_slots = calculate_slots_skipped_by_all_clients(clients_and_data, highest_slot)

    print("Clients and their skipped slots")
    for client in clients_to_skipped_slots:
        print(f'SKIPPED_SLOTS: {client} {clients_to_skipped_slots[client]}')
    # str_slots_to_clients = group_together_similar_slots(clients_to_slots)

    print("Mapping from old hash to new hash")
    [clients_and_data_rehashed, map_to_old_hash] = rehash_parent_hash(clients_and_data)
    for i in map_to_old_hash.items():
        print(f"HASH_MAPPING: {i[0]}: {i[1]}")
    print("====================================================================================\n")
    
    clients_and_data_rehashed_str = stringify_data(clients_and_data_rehashed)
    str_parents_to_clients = group_together_clients_with_similar_slots_or_chains(clients_and_data_rehashed_str, "chain")
    print("Clients with matching chains, chains are in order and the right most hash is the root hash")
    for str_parents_to_client in str_parents_to_clients.items():
        print(f'POTENTIAL_FORKS: {str_parents_to_client}')
    print("====================================================================================\n")
    unsynced_chains_tree = calculate_real_forks_and_unsynced_children(str_parents_to_clients)
    print_real_chains_and_unsynced_children(str_parents_to_clients, unsynced_chains_tree, clients_to_skipped_slots)


class ValidatorStatus:
    def __init__(self, validator_pubkey: str, status: str):
        self.validator_pubkey = validator_pubkey
        self.status = status
    def __str__(self) -> str:
        return f"({self.status}){self.validator_pubkey}"

def get_validators_from_client(clients_to_monitor: list[ClientInstance]):
    validators:list[ValidatorStatus] = []
    client_validators = {"client": "None", "validators": validators}
    # for client, result in perform_batched_request(rpc_request, clients_to_monitor):
    rpc_request = BeaconAPIgetValidators(max_retries=5, timeout=3)
    for client in clients_to_monitor:
        response = rpc_request.perform_request(client)
        if rpc_request.is_valid(response):
            data = rpc_request.get_validators(response)
            for v in data:
                if v:
                    client_validators["validators"].append(ValidatorStatus(v["validator"]["pubkey"], v["status"]))
                else:
                    client_validators["validators"].append(ValidatorStatus("Unknown", "Unknown"))
            client_validators["client"] = client.root_name
            break
    return client_validators

class StatusCheckPerSlotHeadMonitor(TestnetMonitorAction):
    def __init__(self, clients_to_check: list[ClientInstance]):
        super().__init__(
            TestnetMonitorAction("AntithesisStatusCheck", TestnetMonitorActionInterval.EVERY_SLOT),
            get_heads_status_check_slot,
            [clients_to_check],
        )


class TestnetStatusCheckerV2(object):
    # antithesis: fix type for logger arg by adding Optional
    def __init__(self, etb_config: ETBConfig, logger: Optional[logging.Logger] = None):
        self.etb_config: ETBConfig = etb_config

        if logger is None:
            self.logger = logging.getLogger("testnet-status-checker")
        else:
            self.logger = logger

        self.clients_to_monitor = self.etb_config.get_client_instances()
        self.testnet_monitor = TestnetMonitor(self.etb_config)

    def perform_finite_status_check(self, args):

        # go ahead and get the defaults.
        slots_per_epoch = self.etb_config.testnet_config.consensus_layer.preset_base.SLOTS_PER_EPOCH.value
        if args.phase0_slot == -1:
            phase0_slot = slots_per_epoch
        else:
            phase0_slot = args.phase0_slot

        if args.phase1_slot == -1:
            phase1_slot = 2 * slots_per_epoch
        else:
            phase1_slot = args.phase1_slot

        if args.phase2_slot == -1:
            phase2_slot = 3 * slots_per_epoch
        else:
            phase2_slot = args.phase2_slot

        if args.phase3_slot == -1:
            phase3_slot = 4 * slots_per_epoch
        else:
            phase3_slot = args.phase3_slot

        print(f"phase0_slot: {phase0_slot}\nphase1_slot: {phase1_slot}\n", flush=True)
        print(f"phase2_slot: {phase2_slot}\nphase3_slot: {phase3_slot}\n", flush=True)

        self.testnet_monitor.wait_for_slot(phase0_slot)
        # antithesis
        print("Finished waiting for Phase0", flush=True)

        print("checking validator status...", flush=True)
        client_validators = get_validators_from_client(self.clients_to_monitor)
        print(f"validators_count: {len(client_validators['validators'])}", flush=True)
        print(encoder.encode(client_validators), flush=True)
        # print(f"validators: {encoder.encode(validators)}", flush=True)

        # if check_for_consensus(self.clients_to_monitor):
        #     print(f"Phase0 passed.", flush=True)
        # else:
        #     print(f"Phase0 failed.", flush=True)
        #     # antithesis: don't terminate if forks present
        #     print(f"terminate", flush=True)

        # antithesis
        print("start_tx_fuzzer", flush=True)

        self.testnet_monitor.wait_for_slot(phase1_slot)
        print("start_faults", flush=True)

        while self.testnet_monitor.get_slot() < phase2_slot:
            self.testnet_monitor.wait_for_next_slot()
            print(encoder.encode(get_heads_status_check_slot(self.clients_to_monitor)), flush=True)

        print("stop_faults", flush=True)
        print("Phase2 elapsed", flush=True)
        while self.testnet_monitor.get_slot() < phase3_slot:
            self.testnet_monitor.wait_for_next_slot()
            print(encoder.encode(get_heads_status_check_slot(self.clients_to_monitor)), flush=True)

        if check_for_consensus(self.clients_to_monitor):
            print("Phase3 passed.", flush=True)
        else:
            print("Phase3 failed.", flush=True)

        print_all_data_for_every_client(self.clients_to_monitor)
        print("workload_complete", flush=True)

    def perform_indefinite_status_check(self):
        self.logger.debug(
            "Indefinite status check: clients to monitor: %(self.clients_to_monitor)s}"
        )
        per_slot_action = StatusCheckPerSlotHeadMonitor(self.clients_to_monitor)
        self.testnet_monitor.add_action(per_slot_action)
        self.testnet_monitor.start()


if __name__ == "__main__":
    import argparse
    import time

    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--config",
        dest="config",
        required=True,
        help="path to config file to consume for experiment",
    )

    parser.add_argument(
        "--no-terminate",
        dest="no_terminate",
        required=False,
        default=False,
        action="store_true",
        help="Just run the testnet and check the heads every slot. (defaults to true)",
    )

    parser.add_argument(
        "--phase0-slot",
        dest="phase0_slot",
        default=-1,
        type=int,
        help="number of slots to wait before checking initial network health. (defaults to 1st epoch)",
    )

    parser.add_argument(
        "--phase1-slot",
        dest="phase1_slot",
        default=-1,
        type=int,
        help="number of slots to wait until we introduce experiment. (defaults to 2nd epoch)",
    )
    parser.add_argument(
        "--phase2-slot",
        dest="phase2_slot",
        type=int,
        default=-1,
        help="number of slots to wait until we end experiment. (defaults to 3rd epoch)",
    )

    parser.add_argument(
        "--phase3-slot",
        dest="phase3_slot",
        type=int,
        default=-1,
        help="number of slots to wait for the network to heal itself. (defaults to 4th epoch)",
    )

    args = parser.parse_args()
    logging.basicConfig(format="%(asctime)s %(levelname)s: %(message)s", level=logging.DEBUG)
    logger = logging.getLogger()

#    logger.debug("status-check: args=%s", args)

    wait_count = 0
    while not Path(args.config).exists():
        time.sleep(1)
        if wait_count % 10 == 0:
            logger.debug("Waiting for %s -- check %d", args.config, wait_count)
        wait_count += 1

    status_checker = TestnetStatusCheckerV2(ETBConfig(Path(args.config)), logger)

    if args.no_terminate:
        # antithesis
        print("Performing continuous status check.", flush=True)
        status_checker.perform_indefinite_status_check()
    else:
        # antithesis
        print("Performing antithesis experiment.", flush=True)
        status_checker.perform_finite_status_check(args)
