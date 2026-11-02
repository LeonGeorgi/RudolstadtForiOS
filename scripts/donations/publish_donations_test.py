import json
import subprocess
import tempfile
import unittest
from pathlib import Path


PUBLISH = Path(__file__).with_name("publish_donations.sh")


def git(folder, *arguments):
    return subprocess.run(["git", "-C", str(folder), *arguments], check=True,
                          capture_output=True, text=True).stdout.strip()


class PublicationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.remote = self.root / "remote.git"
        self.source = self.root / "source"
        self.source.mkdir()
        git(self.root, "init", "--bare", str(self.remote))
        git(self.source, "init", "--initial-branch=master")
        git(self.source, "config", "user.name", "Offline Test")
        git(self.source, "config", "user.email", "test@example.invalid")
        (self.source / "unrelated.txt").write_text("Source code must not be published")
        git(self.source, "add", ".")
        git(self.source, "commit", "-m", "Initial source")
        git(self.source, "remote", "add", "origin", str(self.remote))
        git(self.source, "push", "origin", "master")
        self.prepared = self.root / "donations.json"
        self.prepared.write_text(json.dumps({"2026": {"EUR": "20.00", "JPY": "1000"}}))

    def publish(self, name):
        return subprocess.run(["bash", str(PUBLISH), str(self.prepared), str(self.source),
                               str(self.root / name)], capture_output=True, text=True)

    def test_first_publication_is_orphan_and_contains_only_aggregate_json(self):
        result = self.publish("publication")
        self.assertEqual(result.returncode, 0, result.stderr)
        files = git(self.remote, "ls-tree", "-r", "--name-only", "donation-data")
        self.assertEqual(files, "donations.json")
        self.assertEqual(git(self.remote, "rev-list", "--count", "donation-data"), "1")
        self.assertEqual(git(self.source, "status", "--porcelain"), "")
        self.assertEqual(json.loads(git(self.remote, "show", "donation-data:donations.json")),
                         {"2026": {"EUR": "20.00", "JPY": "1000"}})

    def test_rerun_is_idempotent_and_updates_replace_instead_of_add(self):
        self.assertEqual(self.publish("first").returncode, 0)
        initial = git(self.remote, "rev-parse", "donation-data")
        self.assertEqual(self.publish("second").returncode, 0)
        self.assertEqual(git(self.remote, "rev-parse", "donation-data"), initial)
        self.prepared.write_text('{"2026":{"EUR":"15.00"}}')
        result = self.publish("third")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(git(self.remote, "show", "donation-data:donations.json")),
                         {"2026": {"EUR": "15.00"}})
        self.assertEqual(git(self.remote, "rev-list", "--count", "donation-data"), "2")

    def test_private_fields_are_rejected_before_creating_branch(self):
        self.prepared.write_text('{"2026":{"EUR":"10.00","customer":"private"}}')
        self.assertNotEqual(self.publish("invalid").returncode, 0)
        self.assertEqual(git(self.remote, "branch", "--list", "donation-data"), "")


if __name__ == "__main__":
    unittest.main()
