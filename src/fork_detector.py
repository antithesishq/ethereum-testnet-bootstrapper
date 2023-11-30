import logging
import requests
from etb.interfaces.client_request import (
    perform_batched_request,
    BeaconAPIgetBlockV2,
    BeaconAPIgetValidators,
)

from etb.config.etb_config import ETBConfig, ClientInstance
from pathlib import Path

from multiprocessing import Pool


def get_all_slots_per_client(client):
    p = "head"
    parents_and_slots = []
    # We are not checking for forks in teku
    # This is a temporary if statement to avoid querying for teku, their api is super slow and will extend the rollout unnecessarily
    if "teku" in client.collection_name :
        return []
    try:
        i = 10
        while (i != 0):
            b = BeaconAPIgetBlockV2(p, max_retries= 2, timeout=15)
            response = b.perform_request(client)
            data = b.get_block(response)
            print(data)
            p = data['parent_root']
            s = data['slot']
            print(f"{client.collection_name}: {[p, s]}")
            parents_and_slots.append([p, s])
            if (p == '0x0000000000000000000000000000000000000000000000000000000000000000' or s == 0):
                # print("End of block has been reached")
                break
            i -= 1
    except Exception as e:
        print(e)
        # It could be possible that we retrieve a response for one slot but not the next slot because of connection issues, this might produce an incomplete chain, therefore we just return the empty chain. No point requering after 15 seconds
        return []
    return [client.collection_name, parents_and_slots]

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
    print(f"parent_chains_sorted: {parents_chains_sorted}")
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
                    print(f"{real_forks}")
                else:
                    real_forks[c2] = c1
        if c1_is_parent:
            parents.append(c1)
    
    # print(parents)
    # print()
    unsynced_chains_tree = {}
    for p in parents:
        if p in real_forks:
            unsynced_chains_tree[p] = real_forks[p]
        else:
            unsynced_chains_tree[p] = ""
    print(f"unsynced_chains_tree: {unsynced_chains_tree}")
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

def print_all_data_for_every_client():
    logger = logging.getLogger()
    etb = ETBConfig(Path("/data/etb-config.yaml"))
    clients = etb.get_client_instances()

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



import time
start = time.time()
epoch = 32 * 2
wait_time = epoch
while (True):
    if (time.time() - start > wait_time):
        start = time.time()
        print_all_data_for_every_client()
    if (wait_time - (time.time() - start) > 0):
        print("WAITING")
        time.sleep(wait_time - (time.time() - start))
    print("WAIT COMPLETE")