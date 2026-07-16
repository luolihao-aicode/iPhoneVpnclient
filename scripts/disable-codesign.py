#!/usr/bin/env python3
"""Patch Xcode project to disable code signing for CI sideload builds."""

import re
import sys

PBXPROJ_PATH = "ios/Runner.xcodeproj/project.pbxproj"

with open(PBXPROJ_PATH, "r") as f:
    content = f.read()

# Replace Automatic signing with Manual + empty team
content = re.sub(
    r"CODE_SIGN_STYLE = Automatic;",
    'CODE_SIGN_STYLE = Manual;\n\t\t\t\tDEVELOPMENT_TEAM = "";',
    content,
)

with open(PBXPROJ_PATH, "w") as f:
    f.write(content)

print("Xcode project patched for unsigned sideload build")
