import importlib.util
import tempfile
import unittest
from pathlib import Path

from PIL import Image, ImageDraw


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "import_addon_skin.py"
SPEC = importlib.util.spec_from_file_location("import_addon_skin", SCRIPT)
IMPORTER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(IMPORTER)


class ImportAddonSkinTests(unittest.TestCase):
    def test_import_generates_valid_static_billboard_and_icons(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            addon = root / "addons" / "Example"
            addon.mkdir(parents=True)
            selection = Image.new("RGBA", (960, 360), (0, 0, 0, 0))
            ImageDraw.Draw(selection).rectangle((120, 40, 300, 350), fill=(40, 180, 90, 255))
            ImageDraw.Draw(selection).rectangle((600, 40, 780, 350), fill=(210, 30, 50, 255))
            selection.save(addon / "selection.png")
            Image.new("RGBA", (64, 64), (10, 20, 30, 255)).save(addon / "portrait.png")
            Image.new("RGBA", (48, 48), (100, 110, 120, 255)).save(addon / "icon.png")

            paths = IMPORTER.convert_addon(addon, root / "coop_art", "P2", "freddy")
            with Image.open(paths[0]) as sheet:
                self.assertEqual(sheet.size, (192, 64))
                frames = [sheet.crop((i * 32, 0, (i + 1) * 32, 64)) for i in range(6)]
                self.assertTrue(all(frame.tobytes() == frames[0].tobytes() for frame in frames[1:]))
                self.assertGreater(frames[0].getchannel("A").getbbox()[2], 0)
            with Image.open(paths[1]) as portrait:
                self.assertEqual(portrait.size, (48, 48))
            with Image.open(paths[2]) as icon:
                self.assertEqual(icon.size, (16, 16))

    def test_import_rejects_empty_selection_art(self):
        with tempfile.TemporaryDirectory() as temp:
            addon = Path(temp) / "addon"
            addon.mkdir()
            Image.new("RGBA", (960, 360), (0, 0, 0, 0)).save(addon / "selection.png")
            with self.assertRaisesRegex(ValueError, "no visible art"):
                IMPORTER.convert_addon(addon, Path(temp) / "out", "P1", "bonnie")


if __name__ == "__main__":
    unittest.main()
