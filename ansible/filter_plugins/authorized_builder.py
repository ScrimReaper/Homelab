#!/usr/bin/python

from pathlib import Path
from typing import List
import warnings 

from cryptography.hazmat.primitives.serialization import load_ssh_public_key


class FilterModule(object):
    def filters(self):
        return {
            'authorized_builder': self.authorized_builder
        }

    def authorized_builder(self, keys: List[str]) -> str:
        """
        receives a list of relative paths to public ssh keys
        and returns a string containing all of them
        """
        key_paths: List[Path] = [Path(p) for p in keys]

        # todo: security
        # ignore deprecated DSA keys (for now)
        warnings.filterwarnings(action='ignore')

        key_contents = []
        for kp in key_paths:
            if not kp.exists():
                raise FileNotFoundError(f"couldn't load ssh pub key: {kp}")

            with kp.open("r") as kf:
                c: str = kf.read().strip()

                # just passing the pub key through pyca/cryptography
                # for input validation
                load_ssh_public_key(c.encode())
                key_contents.append(c)

        return "\n".join(key_contents)
