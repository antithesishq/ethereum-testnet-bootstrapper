"""
    A simple TestnetAction that reports the current:
        head slot (number, root, graffiti) graffiti will default to proposer instance
        finality checkpoints: (current_justified, finalized) (epoch, root)

    The output is organized in terms of forks seen. Roots are represented by
    the last 6 characters of the root.
"""
import logging
import json
import pathlib
import random
import re
import time
from abc import abstractmethod
from typing import Union, Any, Type

import requests
from concurrent.futures import ThreadPoolExecutor

from etb.common.consensus import ConsensusFork, Epoch
from etb.common.utils import create_logger
from etb.config.etb_config import ETBConfig, ClientInstance, get_etb_config
from etb.monitoring.monitors.consensus_monitors import (
    HeadsMonitor,
    CheckpointsMonitor,
    ConsensusLayerPeeringSummary,
    BlobMonitor,
    HeadsMonitorExecutionAvailabilityCheck,
    HeadsMonitorConsensusAvailabilityCheck
)
from etb.monitoring.testnet_monitor import (
    TestnetMonitor,
    TestnetMonitorAction,
    TestnetMonitorActionInterval,
)

from etb.interfaces.external.ethdo import Ethdo


class HeadsMonitorAction(TestnetMonitorAction):
    def __init__(
        self,
        client_instances: list[ClientInstance],
        max_retries: int,
        timeout: int,
        max_retries_for_consensus: int,
        interval: TestnetMonitorActionInterval,
    ):
        super().__init__(name="head_slots", interval=interval)
        self.get_heads_monitor = HeadsMonitor(
            max_retries=max_retries,
            timeout=timeout,
            max_retries_for_consensus=max_retries_for_consensus,
        )
        self.instances_to_monitor = client_instances

    def perform_action(self):
        logging.info("heads:")
        logging.info(f"{self.get_heads_monitor.run(self.instances_to_monitor)}\n")


class CheckpointsMonitorAction(TestnetMonitorAction):
    def __init__(
        self,
        client_instances: list[ClientInstance],
        max_retries: int,
        timeout: int,
        max_retries_for_consensus: int,
        interval: TestnetMonitorActionInterval,
    ):
        super().__init__(name="checkpoints", interval=interval)
        self.get_checkpoints_monitor = CheckpointsMonitor(
            max_retries=max_retries,
            timeout=timeout,
            max_retries_for_consensus=max_retries_for_consensus,
        )
        self.instances_to_monitor = client_instances

    def perform_action(self):
        logging.info("checkpoints:")
        logging.info(f"{self.get_checkpoints_monitor.run(self.instances_to_monitor)}\n")


class PeersMonitorAction(TestnetMonitorAction):
    def __init__(
        self,
        client_instances: list[ClientInstance],
        max_retries: int,
        timeout: int,
        max_retries_for_consensus: int,  # not used.
        interval: TestnetMonitorActionInterval,
    ):
        super().__init__(name="peer-monitor", interval=interval)
        self.get_peering_summary_monitor = ConsensusLayerPeeringSummary(
            max_retries=max_retries,
            timeout=timeout,
        )
        self.instances_to_monitor = client_instances

    def perform_action(self):
        logging.info("peering-info:")
        logging.info(
            f"{self.get_peering_summary_monitor.run(self.instances_to_monitor)}\n"
        )

class HeadsMonitorExecutionAvailabilityCheckAction(TestnetMonitorAction):
    def __init__(
        self,
        client_instances: list[ClientInstance],
        max_retries: int,
        timeout: int,
        max_retries_for_consensus: int,  # not used.
        interval: TestnetMonitorActionInterval,
    ):
        super().__init__(name="head-hash-execution", interval=interval)
        self.get_heads_monitor_execution_availability_check = HeadsMonitorExecutionAvailabilityCheck(
            max_retries=max_retries,
            timeout=timeout,
            max_retries_for_consensus=max_retries_for_consensus,
        )
        self.instances_to_monitor = client_instances

    def perform_action(self):
        # logging.info("heads:")
        logging.info(f"{self.get_heads_monitor_execution_availability_check.run(self.instances_to_monitor)}\n")

class HeadsMonitorConsensusAvailabilityCheckAction(TestnetMonitorAction):
    def __init__(
        self,
        client_instances: list[ClientInstance],
        max_retries: int,
        timeout: int,
        max_retries_for_consensus: int,  # not used.
        interval: TestnetMonitorActionInterval,
    ):
        super().__init__(name="head-slot-consensus", interval=interval)
        self.get_heads_monitor_consensus_availability_check = HeadsMonitorConsensusAvailabilityCheck(
            max_retries=max_retries,
            timeout=timeout,
            max_retries_for_consensus=max_retries_for_consensus,
        )
        self.instances_to_monitor = client_instances

    def perform_action(self):
        # logging.info("heads:")
        logging.info(f"{self.get_heads_monitor_consensus_availability_check.run(self.instances_to_monitor)}\n")

class BlobMonitorAction(TestnetMonitorAction):
    def __init__(
        self,
        client_instances: list[ClientInstance],
        max_retries: int,
        timeout: int,
        max_retries_for_consensus: int,  # not used.
        interval: TestnetMonitorActionInterval,
    ):
        super().__init__(name="blob-monitor", interval=interval)
        self.get_blob_monitor = BlobMonitor(
            max_retries=max_retries,
            timeout=timeout,
        )
        self.instances_to_monitor = client_instances

    def perform_action(self):
        logging.info("blob-info:")
        logging.info(
            f"{self.get_blob_monitor.run(self.instances_to_monitor)}\n"
        )

class EpochPerformanceAction(TestnetMonitorAction):
    def __init__(
        self,
        client_instances: list[ClientInstance],
        max_retries: int,
        timeout: int,
        max_retries_for_consensus: int,  # not used.
        interval: TestnetMonitorActionInterval,
    ):
        super().__init__(name="epoch_performance", interval=interval)
        self.instances_to_monitor = client_instances
        self.ethdo = Ethdo()
        self.max_retries = max_retries

    def perform_action(self):
        summary = None
        random_instance = None
        for i in range(0, self.max_retries):
            random_instance = self.instances_to_monitor[random.randint(0, len(self.instances_to_monitor) - 1)]
            summary = self.ethdo.epoch_summary(f"http://{random_instance.ip_address}:{random_instance.consensus_config.beacon_api_port}", None)
            try:
                epoch_pattern = r'^Epoch\s*(\d+):'
                data_pattern = r'^([\w\s]+):\s*(\d+/\d+)'

                epoch_match = re.search(epoch_pattern, summary)
                data_matches = re.findall(data_pattern, summary, re.MULTILINE)

                data = {"Epoch": epoch_match.group(1)}
                data.update({match[0].strip().replace(' ', '_'): match[1] for match in data_matches})

                json_data = json.dumps(data)
                logging.info(f"epoch_summary:\n{json_data}")
                return

            except:
                logging.error(f"error getting epoch summary {summary} from {random_instance.name} {random_instance.ip_address}")

class PrometheusAction(TestnetMonitorAction):
    def __init__(
        self,
        client_instances: list[ClientInstance],
        max_retries: int,
        timeout: int,
        max_retries_for_consensus: int,  # not used.
        interval: TestnetMonitorActionInterval,
    ):
        super().__init__(name="prometheus", interval=interval)

    def perform_action(self) -> None:
        queries = {
            "cpu_usage": "rate(process_cpu_seconds_total[2m])",
            "libp2p_peers": "libp2p_peers",
            "beacon_head_slot": "beacon_head_slot",
            "beacon_current_justified_epoch": "beacon_current_justified_epoch",
        }

        def _one_request(key, query):
            resp = requests.get(
                "http://prometheus-0:9090/api/v1/query",
                params=dict(query=query)
            )
            if resp.status_code != 200:
                logging.debug(f"prometheus query {query} responded with status code {resp.status_code}, skipping")
                return

            result_all = resp.json()
            if (result_status := result_all["status"]) != "success":
                logging.debug(f"prometheus query {query} has result status {result_status!r}, skipping")
                return

            return key, result_all["data"]

        with ThreadPoolExecutor(max_workers=8) as exc:
            results = dict(exc.map(lambda item: _one_request(*item), queries.items()))

            logging.info(
                json.dumps({"prometheus_metrics": results})
            )


class NodeWatch:
    """
    A class that watches the nodes of a testnet and reports on their status.
    """

    def __init__(
        self,
        args,
        etb_config: ETBConfig,
        max_retries: int,
        timeout: int,
        max_retries_for_consensus: int = 3,
    ):
        """
        etb_config: the ETBConfig for the experiment.
        max_retries: the number of times to retry a request for a single client.
        timeout: the timeout for the requests.
        max_retries_for_consensus: the number of times to retry a series of requests to get consensus among all clients.
        """
        self.etb_config = etb_config
        self.max_retries = max_retries
        self.timeout = timeout
        self.instances_to_monitor = self.etb_config.get_client_instances()
        self.max_retries_for_consensus = max_retries_for_consensus
        self.testnet_monitor = self.build_testnet_monitor(args)

    def build_testnet_monitor(self, cli_args) -> TestnetMonitor:
        """Builds a TestnetMonitor from the args.
        @param args: the args from the command line.
        @return: a TestnetMonitor.
        """
        metrics: dict[
            str, Type[Union[HeadsMonitorAction, CheckpointsMonitorAction, PeersMonitorAction, HeadsMonitorExecutionAvailabilityCheckAction, HeadsMonitorConsensusAvailabilityCheckAction]]
        ] = {
            "heads": HeadsMonitorAction,
            "checkpoints": CheckpointsMonitorAction,
            "peers": PeersMonitorAction,
            "blob": BlobMonitorAction,
            "execution_availability": HeadsMonitorExecutionAvailabilityCheckAction,
            "consensus_availability": HeadsMonitorConsensusAvailabilityCheckAction,
            "prometheus": PrometheusAction,
            "epoch_performance": EpochPerformanceAction,
        }

        intervals = {
            "slot": TestnetMonitorActionInterval.EVERY_SLOT,
            "epoch": TestnetMonitorActionInterval.EVERY_EPOCH,
            "once": TestnetMonitorActionInterval.ONCE,
        }

        testnet_monitor = TestnetMonitor(self.etb_config)
        for monitor in cli_args.monitor:
            metric, interval = monitor.split(":")
            if metric not in metrics:
                raise Exception(f"Unknown metric: {metric}")
            if interval not in intervals:
                raise Exception(f"Unknown interval: {interval}")
            

            _interval = intervals[interval]
            testnet_monitor.add_action(
                metrics[metric](
                    client_instances=self.instances_to_monitor,
                    max_retries=self.max_retries,
                    timeout=self.timeout,
                    max_retries_for_consensus=self.max_retries_for_consensus,
                    interval=_interval,
                )
            )

        return testnet_monitor

    def get_testnet_info_str(self) -> str:
        """Returns str with some information about the running experiment
        @return: str."""
        out = ""
        out += f"genesis time: {self.etb_config.genesis_time}\n"
        out += f"genesis fork version: {self.etb_config.testnet_config.consensus_layer.get_genesis_fork()}\n"

        plausible_forks: list[ConsensusFork] = [
            self.etb_config.testnet_config.consensus_layer.capella_fork,
            self.etb_config.testnet_config.consensus_layer.deneb_fork,
            self.etb_config.testnet_config.consensus_layer.sharding_fork,
        ]

        for fork in plausible_forks:
            if fork.epoch > 0 and fork.epoch != Epoch.FarFuture.value:
                out += f"\tScheduled fork {fork.name} at epoch: {fork.epoch}\n"

        out += "client instances in testnet:\n"
        for instance in self.etb_config.get_client_instances():
            out += f"\t{instance.name} @ {instance.ip_address}\n"
            out += f"\t\tconsensus_client: {instance.consensus_config.client}, execution_client: {instance.execution_config.client}\n"
        return out

    def run(self):
        """Run the node watch printing out the results every slot.

        @return:
        """
        logging.info(self.get_testnet_info_str())
        self.testnet_monitor.run()


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(
        description="Monitor the head and finality checkpoints of a testnet."
    )
    parser.add_argument("--log-level", type=str, default="info", help="Logging level")

    parser.add_argument(
        "--max-retries",
        dest="max_retries",
        type=int,
        default=3,
        help="Max number of retries before " "considering a node unreachable.",
    )

    parser.add_argument(
        "--request-timeout",
        dest="request_timeout",
        type=int,
        default=1,
        help="Timeout for requests to nodes. Note that this "
        "is a timeout for each request, e.g. for one "
        "node we may wait timeout*max_retries seconds.",
    )

    parser.add_argument(
        "--delay",
        dest="delay",
        type=int,
        default=10,
        help="Delay before running the monitor.",
    )

    parser.add_argument(
        "--max-retries-for-consensus",
        dest="max_retries_for_consensus",
        type=int,
        default=3,
        help="Max number of retries before to monitor a metric for consensus.",
    )

    parser.add_argument(
        "--monitor",
        dest="monitor",
        action="append",
        required=True,
        help='The metrics to monitor. The format is "metric:frequency". Possible metrics: heads/checkpoints. '
        "Possible frequencies: once/slot/epoch. For example: --monitor heads:slot --monitor checkpoints:slot",
    )

    parser.add_argument(
        "--log-to-file",
        dest="log_to_file",
        action="store_true",
        default=False,
        help="Log to file.",
    )

    # hidden config option for testing.
    parser.add_argument(
        "--config", dest="config", type=str, default=None, help=argparse.SUPPRESS
    )

    args = parser.parse_args()

    time.sleep(
        args.delay
    )  # if the user is attaching to this instance give them time to do so.
    if args.config is not None:
        logfile = "node_watch.log"
    else:
        logfile = "/data/node_watch.log"

    create_logger(
        name="node_watch",
        log_level=args.log_level.upper(),
        log_to_file=args.log_to_file,
        log_file=logfile,
        format_str="%(message)s",
    )

    logging.info("Getting view of the testnet from etb-config.")
    if args.config is None:
        etb_config: ETBConfig = get_etb_config()
    else:
        logging.warning("Using config from args.")
        etb_config: ETBConfig = ETBConfig(pathlib.Path(args.config))

    node_watcher = NodeWatch(
        etb_config=etb_config,
        max_retries=args.max_retries,
        timeout=args.request_timeout,
        args=args,
    )

    logging.info("Starting node watch.")
    node_watcher.run()
