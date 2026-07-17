#!/usr/bin/env python3
"""
Quick fix: remove the misplaced ForgeVpnPacketTunnel group reference
from inside the RunnerTests group definition, and insert it correctly
in the main group's children list.
"""
import sys
import os

PBXPROJ = "ios/Runner.xcodeproj/project.pbxproj"
GRP_REF = "E1B2C3D4E5F6A1B2C3D4E7F1 /* ForgeVpnPacketTunnel */"

path = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', PBXPROJ)
with open(path) as f:
    content = f.read()

# Find the misplaced line inside RunnerTests definition
# It appears after `RunnerTests = {` and before `isa = PBXGroup;`
misplaced = f'\t\t331C8082294A63A400263BE5 /* RunnerTests */ = {{\n\t\t\t\t{GRP_REF},\n\t\t\tisa = PBXGroup;'
replacement = f'\t\t331C8082294A63A400263BE5 /* RunnerTests */ = {{\n\t\t\tisa = PBXGroup;'

if misplaced in content:
    content = content.replace(misplaced, replacement, 1)
    print("✅ Removed misplaced group ref from RunnerTests definition")
else:
    print("⚠️  Misplaced pattern not found, trying alternative...")
    # Try just removing the line
    old_line = f'\t\t\t\t{GRP_REF},\n'
    new_line = content.replace(old_line, '', 1)
    if new_line != content:
        content = new_line
        print("✅ Removed misplaced line by direct match")

# Now add the group ref correctly to the main group's children
# Find the last child in the main group before )
main_group_start = content.index('97C146E51CF9000F007C117D = {')
children_start = content.index('children = (', main_group_start)
children_end = content.index(');', children_start)
children = content[children_start:children_end]

# Check if it's already there correctly
if f'{GRP_REF},' not in children:
    # Insert after RunnerTests reference in children list
    insert_marker = '331C8082294A63A400263BE5 /* RunnerTests */,'
    insert_pos = children.rfind(insert_marker)
    if insert_pos >= 0:
        children_new = (
            children[:insert_pos + len(insert_marker)] +
            f'\n\t\t\t\t{GRP_REF},' +
            children[insert_pos + len(insert_marker):]
        )
        content = content[:children_start] + children_new + content[children_end:]
        print("✅ Added group ref to main group children")
    else:
        print("⚠️  Could not find RunnerTests in main group children")
else:
    print("✅ Group ref already in main group children")

with open(path, 'w') as f:
    f.write(content)

print("\nDone. Run 'cd ios && pod install' again.")
