import json
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().with_name("publish.sh")


class PublicationTests(unittest.TestCase):
    def test_initial_branch_update_and_no_change_with_local_remote(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            remote = root / "remote.git"
            source = root / "source"
            prepared = root / "prepared"

            def run(*command):
                return subprocess.check_output(command, text=True, stderr=subprocess.STDOUT)

            run("git", "init", "--bare", "--initial-branch=master", str(remote))
            run("git", "init", "--initial-branch=master", str(source))
            run("git", "-C", str(source), "config", "user.name", "Website tests")
            run("git", "-C", str(source), "config", "user.email", "tests@example.invalid")
            run("git", "-C", str(source), "config", "commit.gpgSign", "false")
            run("git", "-C", str(source), "config", "core.hooksPath", "/dev/null")
            run("git", "-C", str(source), "remote", "add", "origin", str(remote))
            config = {
                "name": "festival-leongeorgi", "compatibility_date": "2026-11-02",
                "build": {"command": "python3 scripts/website/build.py"},
                "assets": {"directory": "./artifacts/website", "not_found_handling": "404-page"},
            }
            (source / "wrangler.jsonc").write_text(json.dumps(config))
            (source / "app-source.txt").write_text("App code must not be published")
            run("git", "-C", str(source), "add", ".")
            run("git", "-C", str(source), "commit", "-m", "Initial source")
            for path, content in {
                "rudolstadt/index.html": "Download",
                "rudolstadt/2026/artists/67.html": "Artist 67",
                "_headers": "/.well-known/assetlinks.json\n  Content-Type: application/json\n",
                ".well-known/assetlinks.json": "[]",
                ".well-known/apple-app-site-association": '{"applinks": {}}',
            }.items():
                target = prepared / path
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text(content)

            def publish(name):
                return run("bash", str(SCRIPT), str(prepared), str(source), str(root / name))

            def git_remote(*command):
                return run("git", "--git-dir", str(remote), *command)

            publish("first")
            initial = git_remote("rev-parse", "website-deploy").strip()
            files = git_remote("ls-tree", "-r", "--name-only", "website-deploy").splitlines()
            self.assertNotIn("app-source.txt", files)
            self.assertIn("website/.well-known/assetlinks.json", files)
            self.assertIn("website/.well-known/apple-app-site-association", files)
            deployed = json.loads(git_remote("show", "website-deploy:wrangler.jsonc"))
            self.assertNotIn("build", deployed)
            self.assertEqual(deployed["name"], config["name"])
            self.assertEqual(deployed["assets"]["directory"], "./website")
            self.assertEqual(deployed["assets"]["not_found_handling"], "404-page")

            self.assertIn("unchanged", publish("unchanged"))
            self.assertEqual(git_remote("rev-parse", "website-deploy").strip(), initial)

            (prepared / "rudolstadt/2026/artists/67.html").unlink()
            (prepared / "rudolstadt/2026/artists/23.html").write_text("Artist 23")
            publish("updated")
            files = git_remote("ls-tree", "-r", "--name-only", "website-deploy").splitlines()
            self.assertNotIn("website/rudolstadt/2026/artists/67.html", files)
            self.assertIn("website/rudolstadt/2026/artists/23.html", files)
            self.assertEqual(git_remote("rev-list", "--count", "website-deploy").strip(), "2")
            git_remote("merge-base", "--is-ancestor", initial, "website-deploy")


if __name__ == "__main__":
    unittest.main()
