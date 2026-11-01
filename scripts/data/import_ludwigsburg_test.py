import copy
import hashlib
import io
import unittest

from pypdf import PdfReader, PdfWriter

from import_ludwigsburg import prepare_map_background, prepare_site_plan


class SitePlanCropTests(unittest.TestCase):
    def setUp(self):
        writer = PdfWriter()
        writer.add_blank_page(width=600, height=800)
        output = io.BytesIO()
        writer.write(output)
        self.pdf = output.getvalue()
        self.plan = {
            "sourceSHA256": hashlib.sha256(self.pdf).hexdigest(),
            "sourceCropBox": {"x": 100, "y": 120, "width": 400, "height": 600},
            "locations": [{"id": "stage", "point": {"x": 0.5, "y": 0.5}},
                          {"id": "off-site", "point": None}],
        }

    def test_crop_keeps_the_same_physical_location_and_source_data(self):
        original = copy.deepcopy(self.plan)
        plan, pdf = prepare_site_plan(self.plan, self.pdf)
        page = PdfReader(io.BytesIO(pdf)).pages[0]
        point = plan["locations"][0]["point"]
        self.assertAlmostEqual(float(page.mediabox.left) + point["x"] * float(page.mediabox.width), 300)
        self.assertAlmostEqual(float(page.mediabox.top) - point["y"] * float(page.mediabox.height), 400)
        self.assertEqual(page.mediabox, page.cropbox)
        self.assertEqual(tuple(page.mediabox), (100, 80, 500, 680))
        self.assertIsNone(plan["locations"][1]["point"])
        self.assertEqual(self.plan, original)
        self.assertEqual(plan["sourceSHA256"], hashlib.sha256(pdf).hexdigest())
        self.assertEqual(plan["originalSourceSHA256"], original["sourceSHA256"])

    def test_unchanged_sources_produce_identical_results(self):
        self.assertEqual(prepare_site_plan(self.plan, self.pdf), prepare_site_plan(self.plan, self.pdf))

    def test_changed_source_requires_review_before_cropping(self):
        self.plan["sourceSHA256"] = "unexpected"
        with self.assertRaisesRegex(ValueError, "official site plan changed"):
            prepare_site_plan(self.plan, self.pdf)

    def test_crop_cannot_discard_a_mapped_location(self):
        self.plan["locations"][0]["point"]["x"] = 0.01
        with self.assertRaisesRegex(ValueError, "excludes location stage"):
            prepare_site_plan(self.plan, self.pdf)

    def test_plans_without_a_crop_keep_the_original_pdf(self):
        del self.plan["sourceCropBox"]
        plan, pdf = prepare_site_plan(self.plan, self.pdf)
        self.assertEqual(plan, self.plan)
        self.assertEqual(pdf, self.pdf)

    def test_background_keeps_the_drawing_position_and_removes_foreground_marks(self):
        from PIL import Image
        from reportlab.lib.utils import ImageReader
        from reportlab.pdfgen.canvas import Canvas

        source = io.BytesIO()
        canvas = Canvas(source, pagesize=(600, 800))
        canvas.drawImage(ImageReader(Image.new("RGB", (100, 100), (0, 160, 0))), 100, 200, 400, 400)
        canvas.setFillColorRGB(1, 0, 0)
        canvas.rect(200, 300, 200, 200, fill=1, stroke=0)
        canvas.setFillColorRGB(0, 0, 0)
        canvas.drawString(100, 650, "Printed label")
        canvas.save()
        original = source.getvalue()
        background = Image.open(io.BytesIO(prepare_map_background(original))).convert("RGB")
        self.assertEqual(background.getpixel((background.width // 2, background.height // 2)), (0, 160, 0))
        self.assertEqual(background.getpixel((background.width // 2, background.height // 5)), (255, 255, 255))
        self.assertAlmostEqual(background.width / background.height, 600 / 800, places=3)
        self.assertEqual(background.getextrema()[1], (160, 255))

    def test_missing_background_drawing_requires_source_review(self):
        with self.assertRaisesRegex(ValueError, "drawing changed"):
            prepare_map_background(self.pdf)


if __name__ == "__main__":
    unittest.main()
