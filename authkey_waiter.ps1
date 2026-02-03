# ============================================
# Genshin AuthKey Waiter - One-Line Version
# Command: iwr -useb https://git.io/duke-wish | iex
# GitHub: https://github.com/dukesilvercrypto/duke_gen_wish
# Created by: Duke Silver
# ============================================

# Detect if running via one-line installer
$IsOneLineInstall = $MyInvocation.MyCommand.Name -eq $null

# If not interactive, skip pause at end
if ($IsOneLineInstall) {
    $AutoClose = $true
} else {
    # Check command line arguments
    $AutoClose = $false
}

# Function to show progress
function Write-ProgressMessage([string]$Message) {
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Message" -ForegroundColor Cyan
}

# Function to show result
function Show-Result([string]$AuthKey, [string]$Region) {
    Write-Host ""
    Write-Host "══════════════════════════════════════════" -ForegroundColor Green
    Write-Host "        ✅ AUTHKEY EXTRACTED!            " -ForegroundColor White -BackgroundColor DarkGreen
    Write-Host "══════════════════════════════════════════" -ForegroundColor Green
    Write-Host ""
    Write-Host "🌍 Region: $Region" -ForegroundColor Cyan
    Write-Host "📏 Length: $($AuthKey.Length) characters" -ForegroundColor Gray
    Write-Host ""
    Write-Host "══════════════════════════════════════════" -ForegroundColor Green
    Write-Host "🔑 Your AuthKey:" -ForegroundColor Yellow
    Write-Host "══════════════════════════════════════════" -ForegroundColor Green
    Write-Host ""
    Write-Host $AuthKey -ForegroundColor White
    Write-Host ""
    Write-Host "══════════════════════════════════════════" -ForegroundColor Green
    
    # Copy to clipboard
    try {
        Set-Clipboard -Value $AuthKey
        Write-Host "📋 Copied to clipboard!" -ForegroundColor Green
    } catch {
        Write-Host "⚠️ Could not copy to clipboard" -ForegroundColor Yellow
    }
}

# Main extraction function
function Extract-AuthKey {
    Write-ProgressMessage "Starting Genshin AuthKey extraction..."
    Write-Host ""

    # Check if game is running
    $logPath = "$env:USERPROFILE\AppData\LocalLow\miHoYo\Genshin Impact\output_log.txt"
    $cnLogPath = "$env:USERPROFILE\AppData\LocalLow\miHoYo\$([char]0x539f)$([char]0x795e)\output_log.txt"
    
    if (-not (Test-Path $logPath) -and -not (Test-Path $cnLogPath)) {
        Write-Host "❌ Genshin Impact not detected!" -ForegroundColor Red
        Write-Host ""
        Write-Host "Please:" -ForegroundColor Yellow
        Write-Host "1. Open Genshin Impact" -ForegroundColor Gray
        Write-Host "2. Open Wish History" -ForegroundColor Gray
        Write-Host "3. Run this command again" -ForegroundColor Gray
        return $null
    }
    
    # Determine which log to use
    if (Test-Path $logPath) {
        $gameLog = $logPath
        Write-ProgressMessage "Detected Global server"
    } else {
        $gameLog = $cnLogPath
        Write-ProgressMessage "Detected China server"
    }
    
    # Wait for wish history
    Write-ProgressMessage "Waiting for wish history..."
    Write-Host "   🔄 Please open Wish History in game" -ForegroundColor Yellow
    Write-Host "   ⏱️  Waiting up to 2 minutes..." -ForegroundColor Gray
    
    $startTime = Get-Date
    $timeout = 120  # 2 minutes
    $found = $false
    $authkey = $null
    $region = "Unknown"
    
    while (((Get-Date) - $startTime).TotalSeconds -lt $timeout) {
        try {
            # Read game logs
            $logs = Get-Content $gameLog -ErrorAction Stop
            $gameDirMatch = $logs -match ".:/.+(GenshinImpact_Data|YuanShen_Data)"
            
            if ($gameDirMatch) {
                $gameDirMatch[0] -match "(.:/.+(GenshinImpact_Data|YuanShen_Data))" > $null
                $gameDir = $matches[1]
                
                # Check cache
                $cacheDir = "$gameDir/webCaches"
                if (Test-Path $cacheDir) {
                    $latestCache = Get-ChildItem $cacheDir | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                    $cacheFile = "$($latestCache.FullName)/Cache/Cache_Data/data_2"
                    
                    if (Test-Path $cacheFile) {
                        # Extract authkey
                        $tempFile = "$env:TEMP\duke_wish_$(Get-Random).tmp"
                        Copy-Item $cacheFile $tempFile -Force -ErrorAction Stop
                        
                        $content = Get-Content -Raw $tempFile -ErrorAction Stop
                        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                        
                        # Find URLs with webview_gacha
                        $urls = $content -split "1/0/" | Where-Object { $_ -match "webview_gacha" }
                        
                        foreach ($url in $urls) {
                            if ($url -match "(https.+?game_biz=)") {
                                $fullUrl = $matches[0]
                                
                                # Extract region
                                if ($fullUrl -match '&region=([^&]+)') {
                                    $regionCode = $matches[1]
                                    switch ($regionCode) {
                                        "os_asia" { $region = "Asia" }
                                        "os_usa" { $region = "America" }
                                        "os_euro" { $region = "Europe" }
                                        "os_cht" { $region = "TW/HK/MO" }
                                        default { $region = $regionCode }
                                    }
                                }
                                
                                # Extract authkey
                                if ($fullUrl -match 'authkey=([^&]+)') {
                                    $authkey = $matches[1]
                                    
                                    # Validate length
                                    if ($authkey.Length -gt 100 -and $authkey.Length -lt 5000) {
                                        $found = $true
                                        break
                                    }
                                }
                            }
                        }
                    }
                }
            }
        } catch {
            # Continue waiting
        }
        
        if ($found) {
            break
        }
        
        # Show waiting indicator
        $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds)
        Write-Host "`r⏱️  Waiting... ${elapsed}s" -NoNewline -ForegroundColor Gray
        Start-Sleep -Seconds 2
    }
    
    Write-Host ""
    
    if ($found) {
        return @{ AuthKey = $authkey; Region = $region }
    } else {
        Write-Host "❌ Could not find authkey within timeout" -ForegroundColor Red
        Write-Host ""
        Write-Host "Make sure you:" -ForegroundColor Yellow
        Write-Host "1. Opened Wish History in game" -ForegroundColor Gray
        Write-Host "2. Switched between wish tabs" -ForegroundColor Gray
        Write-Host "3. Waited 10 seconds for data to load" -ForegroundColor Gray
        return $null
    }
}

# Main execution
try {
    $result = Extract-AuthKey
    
    if ($result) {
        Show-Result -AuthKey $result.AuthKey -Region $result.Region
        
        # Wait for user if not auto-close
        if (-not $AutoClose) {
            Write-Host ""
            Write-Host "Press Enter to exit..." -NoNewline
            $null = Read-Host
        }
        
    } else {
        # Exit with error
        if (-not $AutoClose) {
            Write-Host ""
            Write-Host "Press Enter to exit..." -NoNewline
            $null = Read-Host
        }
        exit 1
    }
    
} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    if (-not $AutoClose) {
        Write-Host ""
        Write-Host "Press Enter to exit..." -NoNewline
        $null = Read-Host
    }
    exit 1
}
