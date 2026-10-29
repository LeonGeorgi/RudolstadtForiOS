import tempfile
import unittest
from io import BytesIO
from pathlib import Path
from unittest.mock import patch

from PIL import Image

import embed_artist_images as experiment


class ArtistThumbnailTests(unittest.TestCase):
    def test_relative_thumbnail_url_preserves_percent_encoding(self):
        self.assertEqual(experiment.thumbnail_url('/assets/images/x/Band%C2%A9Test image.jpg'),
                         'https://www.rudolstadt-festival.de/assets/images/x/Band%C2%A9Test%20image.jpg')

    def test_unexpected_host_is_rejected(self):
        with self.assertRaises(ValueError):
            experiment.thumbnail_url('https://example.com/photo.jpg')

    def test_uses_only_thumbnail_field_and_reuses_verified_download(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            cache = root / 'images'
            cache.mkdir()
            content = BytesIO()
            Image.new('RGB', (150, 131)).save(content, format='JPEG')
            (cache / '1.image').write_bytes(content.getvalue())
            artist = {'id': 1, 'name': 'Test', 'img_thumb': '/small.jpg', 'img_full': '/large.jpg'}
            with patch.object(experiment, 'ROOT', root), patch.object(experiment, 'CACHE', cache), \
                    patch.object(experiment, 'urlopen') as request:
                result = experiment.download(artist)
            request.assert_not_called()
            self.assertEqual(result['status'], 'downloaded')
            self.assertTrue(result['url'].endswith('/small.jpg'))
            self.assertEqual((result['width'], result['height']), (150, 131))

    def test_invalid_thumbnail_reports_failure_without_full_image_fallback(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / '1.image').write_bytes(b'<html>Not an image</html>')
            artist = {'id': 1, 'name': 'Test', 'img_thumb': '/small.jpg', 'img_full': '/large.jpg'}
            with patch.object(experiment, 'ROOT', root), patch.object(experiment, 'CACHE', root), \
                    patch.object(experiment, 'urlopen') as request:
                result = experiment.download(artist)
            request.assert_not_called()
            self.assertEqual(result['status'], 'failed')
            self.assertNotIn('path', result)
            self.assertTrue(result['url'].endswith('/small.jpg'))


if __name__ == '__main__':
    unittest.main()
