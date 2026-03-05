import os

def get_asset_sizes(directory):
    asset_data = []
    for root, _, files in os.walk(directory):
        for file in files:
            path = os.path.join(root, file)
            size = os.path.getsize(path) / (1024 * 1024) # Size in MB
            asset_data.append((path, size))
    
    # Sort by size descending
    asset_data.sort(key=lambda x: x[1], reverse=True)
    return asset_data

def main():
    assets_dir = 'assets'
    if not os.path.exists(assets_dir):
        print(f"Directory {assets_dir} not found.")
        return

    asset_data = get_asset_sizes(assets_dir)
    print(f"{'Asset Path':<70} | {'Size (MB)':<10}")
    print("-" * 83)
    for path, size in asset_data[:30]:
        print(f"{path:<70} | {size:>10.2f}")

if __name__ == "__main__":
    main()
