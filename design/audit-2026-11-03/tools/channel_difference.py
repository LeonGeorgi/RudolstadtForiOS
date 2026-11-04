"""Signed grayscale difference: identical pixels are black, Sketch is magenta, Simulator green."""
from argparse import ArgumentParser
from pathlib import Path
from PIL import Image, ImageOps, ImageChops, ImageDraw


def channel_difference(sketch, simulator, ignore_top=0):
    a = ImageOps.grayscale(sketch)
    b = ImageOps.grayscale(simulator)
    if a.size != b.size:
        raise ValueError(f"Image dimensions differ: {a.size} / {b.size}")
    magenta = ImageChops.subtract(b, a)
    green = ImageChops.subtract(a, b)
    result = Image.merge("RGB", (magenta, green, magenta))
    if ignore_top:
        ImageDraw.Draw(result).rectangle((0, 0, result.width - 1, ignore_top - 1), fill="black")
    return result


if __name__ == "__main__":
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("sketch", type=Path)
    parser.add_argument("simulator", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--ignore-top", type=int, default=0, help="Mask this many top rows, in source pixels")
    args = parser.parse_args()
    if args.ignore_top < 0:
        parser.error("--ignore-top must be nonnegative")
    with Image.open(args.sketch) as sketch, Image.open(args.simulator) as simulator:
        channel_difference(sketch, simulator, args.ignore_top).save(args.output)
