"""
ethdo interface
"""
import logging
import pathlib
import subprocess
from typing import Union


class Ethdo:
    """
    ethdo interface
    """

    def __init__(self) -> None:
        pass

    def epoch_summary(self, client: str, epoch: int) -> Union[str, Exception]:
        """ 
            Generate an epoch summary for the consensus node targeted. 
            :param client the consensus node address

            :example:
                root@node-watch-0:/source# ethdo --connection=http://10.0.20.10:5000 --allow-insecure-connections epoch summary --epoch 3
                Epoch 3:
                Proposals: 31/32 (96.88%)
                Attestations: 60/60 (100.00%)
                    Source timely: 60/60 (100.00%)
                    Target correct: 60/60 (100.00%)
                    Target timely: 60/60 (100.00%)
                    Head correct: 60/60 (100.00%)
                    Head timely: 58/60 (96.67%)
                Sync committees: 15700/15872 (98.92%)
        """

        cmd = [
            "ethdo",
            "--allow-insecure-connections"
            "--connection",
            client,
            "epoch",
            "summary",
            "--epoch",
            str(epoch)
        ]
        logging.debug(f"Running command; {cmd}")

        try:
            out = subprocess.run(cmd, capture_output=True, check=True)
            if len(out.stderr) > 0:
                return Exception(out.stderr)
            
            return out.stdout.decode("utf-8")
        except subprocess.CalledProcessError as e:
            return Exception(e.stderr)
