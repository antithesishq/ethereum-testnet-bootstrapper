"""
ethdo interface
"""
import logging
import pathlib
import re
import subprocess
from typing import Union


class Ethdo:
    """
    ethdo interface
    """

    def __init__(self) -> None:
        pass


    def epoch_summary(self, client: str, epoch: int or None) -> Union[str, Exception]:
        """ 
            Generate an epoch summary for the consensus node targeted. 
            :param client the consensus node address

            :example
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

        if epoch is None:
            # Get the current epoch
            current_epoch = 0
            try:
                cmd = ["ethdo", "--connection=" + client, "epoch", "summary"]
                logging.debug(f"Running command: {cmd}")
                out = subprocess.run(
                    cmd, 
                    capture_output=True, text=True
                )
                if len(out.stderr) > 0:
                 return Exception(out.stderr)
                current_epoch_line = next(line for line in out.stdout.split('\n') if 'Epoch' in line)
                match = re.search(r'Epoch (\d+):', current_epoch_line)
                current_epoch = int(match.group(1))
            except subprocess.CalledProcessError as e:
                return Exception(e.stderr)
            
            
            # Calculate the last epoch
            last_epoch = 0
            if current_epoch > 0:
                last_epoch = current_epoch - 1
            logging.debug(f"Last epoch: {last_epoch}")
            

            # Get the epoch summary for the last epoch
            try:
                cmd = ["ethdo", "--allow-insecure-connections", "--connection", client, "epoch", "summary", "--epoch", str(last_epoch)]
                logging.debug(f"Running command; {cmd}")
                out = subprocess.run(
                    cmd, 
                    capture_output=True, check=True
                )
                if len(out.stderr) > 0:
                    return Exception(out.stderr)
                return out.stdout.decode("utf-8")
            except subprocess.CalledProcessError as e:
                return Exception(e.stderr)
            
        else:
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
            logging.debug(f"Running command: {cmd}")

            try:
                out = subprocess.run(cmd, capture_output=True, check=True)
                if len(out.stderr) > 0:
                    return Exception(out.stderr)
                
                return out.stdout.decode("utf-8")
            except subprocess.CalledProcessError as e:
                return Exception(e.stderr)
