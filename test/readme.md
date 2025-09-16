# Local Testing Scripts

This folder contains scripts for local development and testing of the Cesium website.

## Quick Start

### Build the site

```powershell
.\build-and-serve.ps1
```

### Build and serve locally

```powershell
.\build-and-serve.ps1 -serve
```

### Build with verbose output

```powershell
.\build-and-serve.ps1 -verbose
```

### Get help

```powershell
.\build-and-serve.ps1 -help
```

## Available Options

| Option | Short | Description |
|--------|-------|-------------|
| `-verbose` | `-v` | Show detailed output during the build process |
| `-serve` | `-s` | Start the development server after building |
| `-help` | `-h` | Show detailed help and usage information |

All options support both single dash (`-serve`) and double dash (`--serve`) formats.

## What the script does

1. **Creates build directory** and copies the entire workspace (excluding `test/`, `build/`, and `.git/`)
2. **Copy source files** from `src/` to `build/quartz_repo/` (excluding `quartz/` subdirectory)
3. **Apply overrides** from `quartz_overrides/` if they exist
4. **Install dependencies** with `npm ci` in the build directory
5. **Build the site** with `npx quartz build -d ../content`
6. **Optionally serve** the site locally with `npx serve` on port 8080

The script automatically excludes `cesium-src/buildtools` during the copy process to avoid build tool conflicts.

## Testing Custom Components

This script is particularly useful for testing custom components like:

- Custom Explorer with TOC headers
- Custom FolderPage with sortorder
- Custom syntax highlighting
- Any other modifications in the `src/` directory

## Output

Built files are generated in `build/quartz_repo/public/` and can be served locally for testing.

## Troubleshooting

- The script automatically creates a fresh build directory each time, so no manual cleanup is needed
- Use `-verbose` to see detailed error messages and file copy operations
- Ensure you have Node.js and npm installed
- Check that all required directories (`src/`, `content/`, `quartz_repo/`) exist in the repository root
- If the serve option doesn't work, you can manually serve with:

  ```powershell
  cd build\quartz_repo\public
  npx serve . -p 8080
  ```
