# Local build and serve script for Cesium website
# Replicates the GitHub Actions workflow for local testing

param()

$ErrorActionPreference = "Stop"

# Initialize flags
$verbose = $false
$serve = $false
$help = $false

# Parse arguments manually to support both single and double dashes
# $validArgs = @('verbose', 'serve', 'help', 'v', 's', 'h')
$unknownArgs = @()

foreach ($arg in $args) {
    $cleanArg = $arg -replace '^-{1,2}', ''  # Remove leading dashes

    switch ($cleanArg) {
        { $_ -in @('verbose', 'v') } { $verbose = $true }
        { $_ -in @('serve', 's') } { $serve = $true }
        { $_ -in @('help', 'h') } { $help = $true }
        default { $unknownArgs += $arg }
    }
}

# Validate arguments
if ($unknownArgs.Count -gt 0) {
    Write-Host "Error: Unknown argument(s): $($unknownArgs -join ', ')" -ForegroundColor Red
    Write-Host ""
    Show-Help
    exit 1
}

function Show-Help {
    Write-Host @"
Cesium Website Local Build & Test Script

USAGE:
    .\build-and-serve.ps1 [OPTIONS]

OPTIONS:
    -verbose, --verbose, -v    Show detailed output during build
    -serve, --serve, -s        Start development server after building
    -help, --help, -h          Show this help message

EXAMPLES:
    .\build-and-serve.ps1                    # Basic build
    .\build-and-serve.ps1 -serve             # Build and serve
    .\build-and-serve.ps1 --serve            # Build and serve (double dash)
    .\build-and-serve.ps1 -s                 # Build and serve (short form)
    .\build-and-serve.ps1 -verbose           # Build with verbose output
    .\build-and-serve.ps1 --verbose          # Build with verbose output (double dash)
    .\build-and-serve.ps1 --serve --verbose  # Build and serve with verbose output (double dash)

WORKFLOW:
    1. Creates build/ directory and copies entire workspace
    2. Copies source files from src/ to build/quartz_repo/
    3. Applies any quartz_overrides/ if they exist
    4. Installs npm dependencies in build/quartz_repo/
    5. Builds the site with Quartz
    6. Optionally serves the site locally

"@ -ForegroundColor Cyan
}

if ($help) {
    Show-Help
    exit 0
}

Write-Host "Cesium Website Local Build & Test Script" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green

# Get the script directory (repository root)
$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$buildDir = Join-Path $repoRoot "build"

if ($verbose) {
    Write-Host "Repository root: $repoRoot" -ForegroundColor Cyan
    Write-Host "Build directory: $buildDir" -ForegroundColor Cyan
}

# Create build directory and copy entire workspace
Write-Host "Creating build directory and copying entire workspace..." -ForegroundColor Yellow

if (Test-Path $buildDir) {
    if ($verbose) {
        Write-Host "   Removing existing build directory..." -ForegroundColor Gray
    }
    Remove-Item $buildDir -Recurse -Force
}

New-Item -ItemType Directory -Path $buildDir -Force | Out-Null

# Copy entire workspace contents to build directory (like git clone does)
Write-Host "   Copying entire workspace contents..." -ForegroundColor Gray

$itemsCopied = 0
Get-ChildItem $repoRoot -Force | Where-Object {
    # Exclude the build directory itself, test directory, and .git directory to avoid recursion and repo issues
    $_.Name -ne "build" -and $_.Name -ne "test" -and $_.Name -ne ".git"
} | ForEach-Object {
    $destPath = Join-Path $buildDir $_.Name
    if ($_.PSIsContainer) {
        if ($verbose) {
            Write-Host "      Copying directory: $($_.Name)" -ForegroundColor Gray
        }
        # Copy directory but exclude cesium-src/buildtools
        if ($_.Name -eq "cesium-src") {
            # Special handling for cesium-src to exclude buildtools subdirectory
            New-Item -ItemType Directory -Path $destPath -Force | Out-Null
            Get-ChildItem $_.FullName -Force | Where-Object { $_.Name -ne "buildtools" } | ForEach-Object {
                $subDestPath = Join-Path $destPath $_.Name
                if ($_.PSIsContainer) {
                    if ($verbose) {
                        Write-Host "        Copying cesium-src subdirectory: $($_.Name)" -ForegroundColor Gray
                    }
                    Copy-Item $_.FullName $subDestPath -Recurse -Force
                } else {
                    if ($verbose) {
                        Write-Host "        Copying cesium-src file: $($_.Name)" -ForegroundColor Gray
                    }
                    Copy-Item $_.FullName $subDestPath -Force
                }
            }
            if ($verbose) {
                Write-Host "        Excluded: cesium-src/buildtools" -ForegroundColor DarkGray
            }
        } else {
            Copy-Item $_.FullName $destPath -Recurse -Force
        }
    } else {
        if ($verbose) {
            Write-Host "      Copying file: $($_.Name)" -ForegroundColor Gray
        }
        Copy-Item $_.FullName $destPath -Force
    }
    $itemsCopied++
}

Write-Host "   Copied $itemsCopied items to build directory" -ForegroundColor Green

# Set paths to use build directory
$quartzRepo = Join-Path $buildDir "quartz_repo"
$srcDir = Join-Path $buildDir "src"
$contentDir = Join-Path $buildDir "content"

if ($verbose) {
    Write-Host "   Working paths:" -ForegroundColor Cyan
    Write-Host "      Quartz repo: $quartzRepo" -ForegroundColor Gray
    Write-Host "      Source dir: $srcDir" -ForegroundColor Gray
    Write-Host "      Content dir: $contentDir" -ForegroundColor Gray
}


try {
    # Step 1: Copy config/source files to Quartz (equivalent to rsync)
    Write-Host "Copying source files to Quartz repository..." -ForegroundColor Yellow

    Push-Location $quartzRepo

    $filesCopied = 0
    # Copy all files from src/ to quartz_repo/ excluding the quartz/ subdirectory
    Get-ChildItem $srcDir -Recurse | ForEach-Object {
        $relativePath = $_.FullName.Substring($srcDir.Length + 1)

        # Skip files in the quartz/ subdirectory (equivalent to rsync --exclude="/quartz")
        if ($relativePath.StartsWith("quartz\")) {
            if ($verbose) {
                Write-Host "   Skipping: $relativePath" -ForegroundColor DarkGray
            }
            return
        }

        $destPath = Join-Path $quartzRepo $relativePath

        if ($_.PSIsContainer) {
            # Create directory if it doesn't exist
            if (-not (Test-Path $destPath)) {
                New-Item -ItemType Directory -Path $destPath -Force | Out-Null
                if ($verbose) {
                    Write-Host "   Created dir: $relativePath" -ForegroundColor Gray
                }
            }
        } else {
            # Copy file
            $destDir = Split-Path $destPath -Parent
            if (-not (Test-Path $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
            Copy-Item $_.FullName $destPath -Force
            $filesCopied++
            if ($verbose) {
                Write-Host "   Copied: $relativePath" -ForegroundColor Gray
            }
        }
    }

    Write-Host "   Copied $filesCopied files" -ForegroundColor Green

    # Handle quartz_overrides if it exists
    $quartzOverrides = Join-Path $quartzRepo "quartz_overrides"
    if (Test-Path $quartzOverrides) {
        Write-Host "Applying quartz overrides..." -ForegroundColor Yellow
        $quartzDir = Join-Path $quartzRepo "quartz"
        Copy-Item "$quartzOverrides\*" $quartzDir -Recurse -Force
        Write-Host "   Applied overrides to quartz directory" -ForegroundColor Green
    }

    # Step 2: Install Dependencies
    Write-Host "Installing npm dependencies..." -ForegroundColor Yellow

    # Check if package.json exists
    if (-not (Test-Path "package.json")) {
        Write-Error "package.json not found in quartz_repo directory"
        exit 1
    }

    # Use npm ci for clean install (like in CI)
    if ($verbose) {
        Write-Host "   Running: npm ci" -ForegroundColor Gray
    }

    $npmOutput = npm ci 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "npm ci failed with exit code: $LASTEXITCODE`n$npmOutput"
        exit 1
    }

    Write-Host "   Dependencies installed successfully" -ForegroundColor Green

    # Step 3: Build Quartz
    Write-Host "Building Quartz site..." -ForegroundColor Yellow

    # Run the build command
    $buildArgs = @("quartz", "build", "-d", "..\content")
    if ($verbose) {
        Write-Host "   Running: npx $($buildArgs -join ' ')" -ForegroundColor Gray
    }

    $buildOutput = npx @buildArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Quartz build failed with exit code: $LASTEXITCODE`n$buildOutput"
        exit 1
    }

    Write-Host "   Quartz build completed successfully" -ForegroundColor Green

    # Check if public directory was created
    $publicDir = Join-Path $quartzRepo "public"
    if (Test-Path $publicDir) {
        $fileCount = (Get-ChildItem $publicDir -Recurse -File).Count
        Write-Host "Build results:" -ForegroundColor Cyan
        Write-Host "   $fileCount files generated in public/" -ForegroundColor Cyan

        # Show some example files
        if ($verbose) {
            Write-Host "   Sample output files:" -ForegroundColor Cyan
            Get-ChildItem $publicDir -File | Select-Object -First 5 | ForEach-Object {
                Write-Host "      $($_.Name)" -ForegroundColor Gray
            }

            if ($fileCount -gt 5) {
                Write-Host "      ... and $($fileCount - 5) more files" -ForegroundColor Gray
            }
        }
    } else {
        Write-Warning "Public directory not found - build may have failed"
        exit 1
    }

    Write-Host ""
    Write-Host "Build completed successfully!" -ForegroundColor Green

    # Step 4: Serve if requested
    if ($serve) {
        Write-Host ""
        Write-Host "Starting development server..." -ForegroundColor Yellow
        Write-Host "The site will open in your browser automatically" -ForegroundColor Cyan
        Write-Host "Press Ctrl+C to stop the server" -ForegroundColor Cyan
        Write-Host ""

        # Start the server (using serve package since quartz serve doesn't exist in this version)
        Push-Location "public"
        try {
            npx serve . -p 8080
        } finally {
            Pop-Location
        }
    } else {
        Write-Host "Built site is available in: $publicDir" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "To serve locally, run:" -ForegroundColor Yellow
        Write-Host "   .\test\build-and-serve.ps1 -serve" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Or manually:" -ForegroundColor Yellow
        Write-Host "   cd build\quartz_repo\public" -ForegroundColor Gray
        Write-Host "   npx serve . -p 8080" -ForegroundColor Gray
    }

} catch {
    Write-Error "Build failed: $($_.Exception.Message)"
    if ($verbose) {
        Write-Host "Stack trace:" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace -ForegroundColor Red
    }
    exit 1
} finally {
    Pop-Location
}
