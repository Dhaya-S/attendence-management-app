"""
Fix const BoxDecoration that contain Border.all() — 
Border.all() is not const, so we need to remove 'const' from the parent BoxDecoration.
Also check for cases where the border line itself has 'const' before Color.
"""
import os
import re

LIB_DIR = r"c:\Users\archana\OneDrive\Desktop\app2\app1\lib"

def fix_const_border_issues(content):
    """
    For each line with Border.all(color: const Color(...)):
    1. Look backwards for the parent 'const BoxDecoration(' and remove 'const' from it
    2. Remove 'const' before Color inside Border.all since the parent is no longer const
    """
    lines = content.split('\n')
    
    # First pass: find all lines with Border.all and track which BoxDecoration parents need const removed
    border_lines = []
    for i, line in enumerate(lines):
        if 'border: Border.all(color: const Color(0xFFF0F1F3)' in line:
            border_lines.append(i)
    
    # For each border line, look backwards for 'const BoxDecoration(' and remove const
    const_decoration_lines_to_fix = set()
    for bl in border_lines:
        for j in range(bl - 1, max(bl - 10, -1), -1):
            if 'const BoxDecoration(' in lines[j]:
                const_decoration_lines_to_fix.add(j)
                break
    
    # Apply fixes
    for line_idx in const_decoration_lines_to_fix:
        lines[line_idx] = lines[line_idx].replace('const BoxDecoration(', 'BoxDecoration(')
    
    return '\n'.join(lines)


def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    if 'border: Border.all(color: const Color(0xFFF0F1F3)' not in content:
        return False
    
    original = content
    content = fix_const_border_issues(content)
    
    if content != original:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"  Fixed: {os.path.basename(filepath)}")
        return True
    return False


def main():
    count = 0
    for root, dirs, files in os.walk(LIB_DIR):
        for fname in files:
            if fname.endswith('.dart'):
                fpath = os.path.join(root, fname)
                if process_file(fpath):
                    count += 1
    print(f"\nTotal files fixed: {count}")


if __name__ == '__main__':
    main()
