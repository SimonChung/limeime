#!/usr/bin/env python3
# Add all *_ipad.json layout files to LimeIME.xcodeproj/project.pbxproj.
# Usage: python3 .claude/scripts/add_ipad_layouts_to_xcodeproj.py

import re, os, uuid, glob

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT   = os.path.normpath(os.path.join(SCRIPT_DIR, '../..'))
PBXPROJ     = os.path.join(REPO_ROOT, 'LimeIME-iOS/LimeIME.xcodeproj/project.pbxproj')
LAYOUTS_DIR = os.path.join(REPO_ROOT, 'LimeIME-iOS/LimeKeyboard/Layouts')

def gen_uuid():
    return uuid.uuid4().hex.upper()[:24]

# Collect files to add
ipad_files = sorted(
    os.path.basename(f)
    for f in glob.glob(os.path.join(LAYOUTS_DIR, '*_ipad.json'))
)
print(f'Adding {len(ipad_files)} _ipad.json files to xcodeproj')

content = open(PBXPROJ, encoding='utf-8').read()

# Check which files are already present
already = set(re.findall(r'/\* ([\w.]+) \*/ = \{isa = PBXFileReference', content))
to_add = [f for f in ipad_files if f not in already]
if not to_add:
    print('All files already in project.')
    exit(0)
print(f'  Need to add: {len(to_add)} files')

# Generate UUIDs: fileref_uuid → filename, buildfile_uuid → fileref_uuid
entries = []
for fname in to_add:
    fr_uuid = gen_uuid()
    bf_uuid = gen_uuid()
    entries.append((fname, fr_uuid, bf_uuid))

# ── 1. Add PBXFileReference entries ─────────────────────────────────────────
# Insert after the last existing .json PBXFileReference line
fr_lines = '\n'.join(
    f'\t\t{fr} /* {fn} */ = {{isa = PBXFileReference; lastKnownFileType = text.json; '
    f'name = "{fn}"; path = "Layouts/{fn}"; sourceTree = "<group>"; }};'
    for fn, fr, _ in entries
)
# Find anchor: last json PBXFileReference line
fr_anchor = re.search(
    r'(\t\t\w+ /\* [\w.]+\.json \*/ = \{isa = PBXFileReference[^\n]+\n)',
    content
)
# Insert after the last such line — use split on the section end marker
content = re.sub(
    r'(/\* End PBXFileReference section \*/)',
    fr_lines + '\n\t\t\\1',
    content,
    count=1
)

# ── 2. Add PBXBuildFile entries ──────────────────────────────────────────────
bf_lines = '\n'.join(
    f'\t\t{bf} /* {fn} in Resources */ = {{isa = PBXBuildFile; fileRef = {fr} /* {fn} */; }};'
    for fn, fr, bf in entries
)
content = re.sub(
    r'(/\* End PBXBuildFile section \*/)',
    bf_lines + '\n\t\t\\1',
    content,
    count=1
)

# ── 3. Add to Layouts PBXGroup children ──────────────────────────────────────
group_children = '\n'.join(
    f'\t\t\t\t{fr} /* {fn} */,'
    for fn, fr, _ in entries
)
# Insert into the Layouts group children list
# Find "/* Layouts */ = { ... children = ( ... )"
def insert_into_group(m):
    original = m.group(0)
    # Find the closing paren of children list and insert before it
    insert_point = original.rfind('\t\t\t);')
    if insert_point == -1:
        return original
    return original[:insert_point] + group_children + '\n' + original[insert_point:]

content = re.sub(
    r'/\* Layouts \*/ = \{[^}]+children = \([^)]+\)',
    insert_into_group,
    content,
    flags=re.DOTALL,
    count=1
)

# ── 4. Add to Resources build phase files list ──────────────────────────────
# Find the "Resources" PBXResourcesBuildPhase files list and append there
resources_files = '\n'.join(
    f'\t\t\t\t{bf} /* {fn} in Resources */,'
    for fn, _, bf in entries
)

def insert_into_resources(m):
    original = m.group(0)
    insert_point = original.rfind('\t\t\t);')
    if insert_point == -1:
        return original
    return original[:insert_point] + resources_files + '\n' + original[insert_point:]

content = re.sub(
    r'(/\* Resources \*/ = \{[^}]+isa = PBXResourcesBuildPhase[^}]+files = \([^)]+\))',
    insert_into_resources,
    content,
    flags=re.DOTALL,
    count=1
)

with open(PBXPROJ, 'w', encoding='utf-8') as f:
    f.write(content)

print(f'Done. Added {len(entries)} files to {PBXPROJ}')
for fn, fr, bf in entries:
    print(f'  {fn}  (fileRef={fr}, buildFile={bf})')
