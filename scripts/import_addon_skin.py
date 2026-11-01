#!/usr/bin/env python3
"""Convert one Frickbear's 3LD custom-guard add-on into static co-op skin PNGs."""
import argparse
from pathlib import Path

from PIL import Image, ImageOps

FRAME_SIZE = (32, 64)


def selection_frame(path: Path) -> Image.Image:
    with Image.open(path) as source:
        image = source.convert("RGBA")
    if image.width < 2:
        raise ValueError(f"{path} must contain a two-frame horizontal selection sheet")
    first = image.crop((0, 0, image.width // 2, image.height))
    bounds = first.getchannel("A").getbbox()
    if bounds is None:
        raise ValueError(f"{path} has no visible art in its first frame")
    return first.crop(bounds)


def convert_addon(addon_dir: Path, output_dir: Path, seat: str, mask: str) -> list[Path]:
    art = selection_frame(addon_dir / "selection.png")
    art.thumbnail(FRAME_SIZE, Image.Resampling.LANCZOS)
    frame = Image.new("RGBA", FRAME_SIZE, (0, 0, 0, 0))
    frame.alpha_composite(art, ((FRAME_SIZE[0] - art.width) // 2, FRAME_SIZE[1] - art.height))
    sheet = Image.new("RGBA", (FRAME_SIZE[0] * 6, FRAME_SIZE[1]), (0, 0, 0, 0))
    for index in range(6):
        sheet.alpha_composite(frame, (index * FRAME_SIZE[0], 0))

    portrait_path = addon_dir / "portrait.png"
    icon_path = addon_dir / "icon.png"
    portrait_source = portrait_path if portrait_path.is_file() else addon_dir / "selection.png"
    icon_source = icon_path if icon_path.is_file() else portrait_source
    with Image.open(portrait_source) as source:
        portrait = ImageOps.fit(source.convert("RGBA"), (48, 48), method=Image.Resampling.LANCZOS)
    with Image.open(icon_source) as source:
        icon = ImageOps.fit(source.convert("RGBA"), (16, 16), method=Image.Resampling.LANCZOS)

    output_dir.mkdir(parents=True, exist_ok=True)
    outputs = [
        output_dir / f"{seat}_{mask}_bill.png",
        output_dir / f"{seat}_{mask}_portrait.png",
        output_dir / f"{seat}_{mask}_icon.png",
    ]
    for image, output in zip((sheet, portrait, icon), outputs):
        image.save(output)
    return outputs


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("addon_dir", type=Path, help="custom guard folder containing selection.png")
    parser.add_argument("--seat", choices=("P1", "P2"), default="P2")
    parser.add_argument("--mask", choices=("freddy", "bonnie", "chica"), default="freddy")
    parser.add_argument("--output", type=Path, default=Path.cwd() / "coop_art")
    args = parser.parse_args()
    for path in convert_addon(args.addon_dir, args.output, args.seat, args.mask):
        print(path)
    print("Imported as a static six-frame skin; edit the frames to add animation.")


if __name__ == "__main__":
    main()
