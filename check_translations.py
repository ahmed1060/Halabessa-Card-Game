import re
import os
import json

def get_keys_from_code(directory):
    keys = set()
    # Pattern to match '.tr()' calls with single or double quotes
    pattern = re.compile(r'[\'\"]([a-zA-Z0-9_-]+)[\'\"]\.tr\(')
    
    for root, _, files in os.walk(directory):
        for file in files:
            if file.endswith('.dart'):
                with open(os.path.join(root, file), 'r', encoding='utf-8', errors='ignore') as f:
                    content = f.read()
                    matches = pattern.findall(content)
                    keys.update(matches)
    return keys

def get_keys_from_json(filepath):
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            data = json.load(f)
            return set(data.keys())
    except Exception as e:
        print(f"Error reading {filepath}: {e}")
        return set()

def main():
    lib_dir = 'lib'
    translation_files = {
        'en-US': 'assets/translations/en-US.json',
        'ar-EG': 'assets/translations/ar-EG.json',
        'ar-SA': 'assets/translations/ar-SA.json'
    }
    
    code_keys = get_keys_from_code(lib_dir)
    print(f"Found {len(code_keys)} unique keys in code.")
    
    all_missing = {}
    cross_missing = {}
    
    # Check code keys against JSONs
    for lang, path in translation_files.items():
        json_keys = get_keys_from_json(path)
        missing = code_keys - json_keys
        if missing:
            all_missing[lang] = sorted(list(missing))
            
    # Check cross-JSON consistency
    all_json_keys = {}
    for lang, path in translation_files.items():
        all_json_keys[lang] = get_keys_from_json(path)
        
    master_keys = set().union(*all_json_keys.values())
    
    for lang, keys in all_json_keys.items():
        missing_cross = master_keys - keys
        if missing_cross:
            cross_missing[lang] = sorted(list(missing_cross))
            
    if not all_missing and not cross_missing:
        print("No missing keys found!")
    else:
        if all_missing:
            print("\n!!! MISSING KEYS (IN CODE BUT NOT IN JSON) !!!")
            for lang, missing in all_missing.items():
                print(f"\n[{lang}] is missing:")
                for key in missing:
                    print(f"  - {key}")
        
        if cross_missing:
            print("\n\n!!! INCONSISTENT KEYS (IN ONE JSON BUT NOT ANOTHER) !!!")
            for lang, missing in cross_missing.items():
                print(f"\n[{lang}] is missing these keys (present in other languages):")
                for key in missing:
                    print(f"  - {key}")

if __name__ == "__main__":
    main()
