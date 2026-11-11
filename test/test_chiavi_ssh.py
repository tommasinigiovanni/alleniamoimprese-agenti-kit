import importlib.util
from pathlib import Path
import os
import pwd
import subprocess
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location('chiavi', Path(__file__).resolve().parents[1] / 'profili/chiavi_ssh.py')
chiavi = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(chiavi)


class AuthorizedKeysTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / 'root-authorized_keys'
        self.target = self.root / 'agente/.ssh/authorized_keys'
        self.owner = pwd.getpwuid(os.getuid()).pw_name
        self.keys = []
        for i in range(2):
            key = self.root / f'key-{i}'
            subprocess.run(['ssh-keygen', '-q', '-t', 'ed25519', '-N', '', '-f', str(key)], check=True)
            self.keys.append(key.with_suffix('.pub').read_text().strip())

    def authorize(self):
        chiavi.authorize(self.source, self.target, self.owner)

    def test_multiple_keys_idempotency_and_permissions(self):
        self.source.write_text('# Hetzner\n' + '\n'.join(self.keys + [self.keys[0]]) + '\n')
        self.authorize()
        first = self.target.read_text()
        self.authorize()
        self.assertEqual(self.target.read_text(), first)
        self.assertEqual(len(first.splitlines()), 2)
        self.assertEqual(self.target.stat().st_mode & 0o777, 0o600)
        self.assertEqual(self.target.parent.stat().st_mode & 0o777, 0o700)
        self.assertEqual(self.target.stat().st_uid, os.getuid())

    def test_existing_key_is_preserved(self):
        self.source.write_text(self.keys[0] + '\n')
        self.target.parent.mkdir(parents=True)
        self.target.write_text('# aggiunta dallo studente\n' + self.keys[1] + '\n')
        self.authorize()
        self.assertIn(self.keys[1], self.target.read_text())
        self.assertIn(self.keys[0], self.target.read_text())

    def test_missing_empty_invalid_and_restricted_keys_do_not_change_destination(self):
        self.target.parent.mkdir(parents=True)
        self.target.write_text(self.keys[1] + '\n')
        for content in ('', '# nessuna chiave\n', 'ssh-ed25519 non-valida\n',
                        'command="exit 142" ' + self.keys[0] + '\n'):
            with self.subTest(content=content):
                self.source.write_text(content)
                with self.assertRaises(ValueError):
                    self.authorize()
                self.assertEqual(self.target.read_text(), self.keys[1] + '\n')

    def test_symlink_destination_is_rejected(self):
        self.source.write_text(self.keys[0] + '\n')
        other = self.root / 'other'
        other.write_text('non modificare')
        self.target.parent.mkdir(parents=True)
        self.target.symlink_to(other)
        with self.assertRaises(ValueError):
            self.authorize()
        self.assertEqual(other.read_text(), 'non modificare')


if __name__ == '__main__':
    unittest.main()
