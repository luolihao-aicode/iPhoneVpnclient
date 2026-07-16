#!/usr/bin/env python3
"""Patch Xcode project to disable code signing for CI sideload builds.

This script:
  1. Adds CODE_SIGN_STYLE = Manual + empty DEVELOPMENT_TEAM to Runner target
     build configs (Debug, Release, Profile) so 'flutter build --no-codesign'
     passes its post-build validation check.
  2. Replaces any existing CODE_SIGN_STYLE = Automatic with Manual + empty team
     (handles RunnerTests target).
"""

import re
import sys

PBXPROJ_PATH = "ios/Runner.xcodeproj/project.pbxproj"

with open(PBXPROJ_PATH, "r") as f:
    content = f.read()

# ── 1. Replace any existing CODE_SIGN_STYLE = Automatic → Manual + empty team ──
content = re.sub(
    r"CODE_SIGN_STYLE = Automatic;",
    'CODE_SIGN_STYLE = Manual;\n\t\t\t\tDEVELOPMENT_TEAM = "";',
    content,
)

# ── 2. Add CODE_SIGN_STYLE + empty DEVELOPMENT_TEAM to Runner target build
#       configs if not already present. The Runner target blocks are
#       identified by containing PRODUCT_BUNDLE_IDENTIFIER = com.example.forgeVpnFlutter;
#       and NOT containing CODE_SIGN_STYLE (since we just replaced it above).
# ──
# Each block looks like:
#   name = Debug;   ← at end of block
#   name = Release;
#   name = Profile;
# We inject before the closing "};" of each block that has the Flutter bundle ID
# but lacks CODE_SIGN_STYLE.

runner_pattern = re.compile(
    r'(PRODUCT_BUNDLE_IDENTIFIER = com\.example\.forgeVpnFlutter;'
    r'.*?)'
    r'(\t+);\n\t\t\tname = (Debug|Release|Profile);',
    re.DOTALL,
)

def runner_patch(m):
    body = m.group(1)
    indent = m.group(2)
    config_name = m.group(3)
    if 'CODE_SIGN_STYLE' in body:
        return m.group(0)  # already patched
    patch = (
        f'{indent}CODE_SIGN_STYLE = Manual;\n'
        f'{indent}DEVELOPMENT_TEAM = "";'
    )
    return f'{body}{patch}\n{indent});\n\t\t\tname = {config_name};'

content = runner_pattern.sub(runner_patch, content)

with open(PBXPROJ_PATH, "w") as f:
    f.write(content)

print("Xcode project patched for unsigned sideload build (Runner + RunnerTests)")
