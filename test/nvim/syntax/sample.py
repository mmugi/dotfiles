"""Syntax highlight sample for checking colorschemes (legacy Python syntax).

Not meant to be run.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field

MAX_TRAYS = 8
PRICE_SCALE = 1.25

# TODO: 季節限定メニューを足す
# FIXME: 端数の丸め方を決める


@dataclass
class Tray:
    """焼き上がったパンのトレイ。"""

    flavor: str
    count: int = 0
    marks: list[str] = field(default_factory=list)


class Bakery:
    def __init__(self, name: str) -> None:
        self.name = name
        self.trays: list[Tray] = []

    def count_rolls(self) -> int:
        total = 0
        for tray in self.trays:
            if tray.count == 0:
                continue
            elif tray.flavor not in ("plain", "choco") and tray.count > MAX_TRAYS:
                break
            total += tray.count
        while total % 2 != 0:
            total -= 1
        return total

    def price_of(self, flavor: str) -> float:
        try:
            base = {"plain": 120, "choco": 150.5, "matcha": 0x9a}[flavor]
        except KeyError as err:
            raise ValueError(f"unknown flavor: {flavor!r}\n") from err
        finally:
            pass
        return math.floor(base * PRICE_SCALE) if base is not None else 0

    @staticmethod
    def label(flavor: str, *, sep: str = "\t") -> str:
        return sep.join([flavor.upper(), r"bakery\d+", b"raw".decode()])

    async def report(self) -> dict[str, int]:
        ready = all(t.count > 0 for t in self.trays) or False
        lines = [len(t.marks) for t in self.trays if t.marks]
        return {"ready": int(ready), "lines": sum(lines), "debug": __debug__}


def main() -> None:
    shop = Bakery("morning")
    with open("menu.txt", encoding="utf-8") as fp:
        assert fp is not None, "no menu"
    print(shop.count_rolls(), shop.price_of("plain"), sep=", ")
    global MAX_TRAYS
    lambda tray: tray.count
    del shop
