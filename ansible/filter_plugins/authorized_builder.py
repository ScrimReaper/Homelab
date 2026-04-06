#!/usr/bin/python

from pathlib import Path
from typing import List
import warnings
from cryptography.hazmat.primitives.serialization import load_ssh_public_key
from cryptography.utils import CryptographyDeprecationWarning


class FilterModule(object):
    def filters(self):
        return {"authorized_builder": self.authorized_builder}

    def authorized_builder(self, keys: List[str], base_dir: str = "") -> str:
        key_contents = []
        for key in keys:
            kp = Path(base_dir) / key if base_dir else Path(key)
            if not kp.exists():
                raise FileNotFoundError(f"SSH public key not found: {kp}")

            c = kp.read_text(encoding="utf-8").strip().replace("\r\n", "\n")

            # todo: security
            with warnings.catch_warnings():
                warnings.filterwarnings(
                    "ignore", category=CryptographyDeprecationWarning
                )
                try:
                    load_ssh_public_key(c.encode())
                except Exception as e:
                    raise ValueError(f"Invalid SSH public key '{kp}': {e}") from e

            key_contents.append(c)

        return "\n".join(key_contents)
