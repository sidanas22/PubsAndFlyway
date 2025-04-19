param(
    [Parameter(Mandatory=$true)]
    [string]$Version,
    
    [Parameter(Mandatory=$true)]
    [string]$Description,
    
    [Parameter(Mandatory=$false)]
    [string]$ScriptsPath = ".\Scripts",

    [Parameter(Mandatory=$false)]
    [switch]$UseShortVersion
)

# Convert description to use underscores instead of spaces
$Description = $Description.Replace(" ", "_")

# Get current epoch timestamp
$Epoch = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()

# Determine version format
$VersionForFolder = $Version
if ($UseShortVersion) {
    # Extract major.minor for folder (e.g., "2.1" from "2.1.0")
    $VersionForFolder = $Version -replace '^(\d+\.\d+).*', '$1'
}

# Create filename using the pattern
$FileName = "V${Version}_${Epoch}__${Description}.sql"

# Create the version folder path
$FullPath = Join-Path $ScriptsPath "V$VersionForFolder"
$FilePath = Join-Path $FullPath $FileName

# Create version folder if it doesn't exist
if (-not (Test-Path $FullPath)) {
    New-Item -ItemType Directory -Path $FullPath -Force
}

# Create empty SQL file with a header comment
@"
-- Migration Script
-- Version: $Version
-- Description: $($Description.Replace("_", " "))
-- Created: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

"@ | Out-File -FilePath $FilePath -Encoding UTF8

Write-Host "Created migration file: $FilePath"


# You can use this script in two ways:

# For full version format (V2.1.0):
# For short version format (V2.1):
# The script will:

# Create V2.1.0_1744747999__Add_new_feature.sql in folder V2.1.0 when used normally
# Create V2.1.0_1744747999__Add_new_feature.sql in folder V2.1 when using -UseShortVersion
# Add a header comment with metadata
# Use UTF8 encoding
# Create the version folder if it doesn't exist
# The difference is only in the folder structure, while the filename always keeps the full version number for proper ordering.