#!/usr/bin/env python3
"""Fail closed when SDK, translations, or public-build secret policy drifts."""
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parents[2]
version = json.loads((root / '.fvmrc').read_text())['flutter']
for path in (root / '.github/workflows').glob('*.yml'):
    text = path.read_text()
    match = re.search(r"FLUTTER_VERSION: ['\"]([^'\"]+)", text)
    if match:
        assert match[1] == version, f'{path.name}: SDK differs from .fvmrc'
    assert 'secrets.SILICONFLOW_KEY' not in text, f'{path.name}: shared key injection'
    if 'softprops/action-gh-release' in text:
        assert text.count('draft: true') == text.count('softprops/action-gh-release'), path

setup = (root / '.github/actions/setup-flutter/action.yml').read_text()
assert f"SDK_VERSION: '{version}'" in setup, 'SDK installer version mismatch'

locales = ['en', 'zh', 'zh_Hans', 'zh_Hant']
arbs = [json.loads((root / f'lib/l10n/app_{locale}.arb').read_text()) for locale in locales]
keys = {key for key in arbs[0] if not key.startswith('@')}
for locale, arb in zip(locales, arbs):
    assert {key for key in arb if not key.startswith('@')} == keys, f'{locale}: key mismatch'
    for key in keys:
        expected = arbs[0].get('@' + key, {}).get('placeholders', {})
        actual = arb.get('@' + key, {}).get('placeholders', {})
        assert actual == expected, f'{locale}: {key} placeholder mismatch'
for tree in ['lib', 'test', 'integration_test', 'tool']:
    for path in (root / tree).rglob('*.dart'):
        text = path.read_text()
        assert 'package:Kelivo/' not in text, f'{path}: wrong package import'
        assert not re.search(r'^<<<<<<< |^>>>>>>> ', text, re.M), f'{path}: conflict marker'
print(f'Release contracts passed: Flutter {version}, four locales, no shared key injection.')
