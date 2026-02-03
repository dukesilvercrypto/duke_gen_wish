
## **`authkey_waiter.ps1`** (Final Clean Version):

```powershell
# ============================================
# Genshin AuthKey Waiter
# Created by: Duke Silver
# GitHub: https://github.com/dukesilvercrypto/genshin-authkey-waiter
# ============================================

# Clear screen
Clear-Host

# Show header
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   Genshin AuthKey Waiter              " -ForegroundColor White
Write-Host "   by Duke Silver                      " -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Status: Waiting..." -ForegroundColor Yellow
Write-Host ""

# Function to show progress
function Show-Progress([string]$message) {
    Write-Host "`r[$((Get-Date).ToString('HH:mm:ss'))] $message" -ForegroundColor Gray -NoNewline
}

# Function to show success
function Show-Success([string]$message) {
    Write-Host "`r[✓] $message" -ForegroundColor Green
}

# Function to show error
function Show-Error([string]$message) {
    Write-Host "`r[✗] $message" -ForegroundColor Red
}

# Main waiting function
function Wait-ForAuthKey {
    $startTime = Get-Date
    $timeout = 600  # 10 minutes
    
    # Step 1: Wait for game
    Show-Progress "Waiting for Genshin Impact..."
    while ($true) {
        # Check for game logs
        $logPath = "$env:USERPROFILE\AppData\LocalLow\miHoYo\Genshin Impact\output_log.txt"
        $cnLogPath = "$env:USERPROFILE\AppData\LocalLow\miHoYo\$([char]0x539f)$([char]0x795e)\output_log.txt"
        
        if (Test-Path $logPath) {
            $gameLog = $logPath
            Show-Success "Game detected (Global)"
            break
        }
        elseif (Test-Path $cnLogPath) {
            $gameLog = $cnLogPath
            Show-Success "Game detected (China)"
            break
        }
        
        # Check timeout
        if (((Get-Date) - $startTime).TotalSeconds -gt $timeout) {
            Show-Error "Timeout: Game not found"
            return $null
        }
        
        Start-Sleep -Seconds 2
    }
    
    # Step 2: Wait for wish history
    Show-Progress "Waiting for wish history..."
    while ($true) {
        try {
            # Read game directory from logs
            $logs = Get-Content $gameLog -ErrorAction Stop
            $gameDirMatch = $logs -match ".:/.+(GenshinImpact_Data|YuanShen_Data)"
            
            if ($gameDirMatch) {
                $gameDirMatch[0] -match "(.:/.+(GenshinImpact_Data|YuanShen_Data))" > $null
                $gameDir = $matches[1]
                
                # Check cache
                $cacheDir = "$gameDir/webCaches"
                if (Test-Path $cacheDir) {
                    $latestCache = Get-ChildItem $cacheDir | Sort LastWriteTime -Desc | Select -First 1
                    $cacheFile = "$($latestCache.FullName)/Cache/Cache_Data/data_2"
                    
                    if (Test-Path $cacheFile) {
                        # Extract authkey
                        $tempFile = "$env:TEMP\auth_temp_$(Get-Random).bin"
                        Copy-Item $cacheFile $tempFile -Force
                        
                        $content = Get-Content -Raw $tempFile
                        Remove-Item $tempFile -Force
                        
                        # Find authkey in cache
                        $urls = $content -split "1/0/" | Where {$_ -match "webview_gacha"}
                        
                        foreach ($url in $urls) {
                            if ($url -match "(https.+?game_biz=)") {
                                $fullUrl = $matches[0]
                                
                                # Extract region
                                if ($fullUrl -match '&region=([^&]+)') {
                                    $region = $matches[1]
                                }
                                
                                # Extract authkey
                                if ($fullUrl -match 'authkey=([^&]+)') {
                                    $authkey = $matches[1]
                                    
                                    # Return result
                                    return @{
                                        Success = $true
                                        AuthKey = $authkey
                                        Region = $region
                                        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
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
        
        # Check timeout
        if (((Get-Date) - $startTime).TotalSeconds -gt $timeout) {
            Show-Error "Timeout: Wish history not opened"
            return $null
        }
        
        Start-Sleep -Seconds 3
    }
}

# Main execution
try {
    $result = Wait-ForAuthKey
    
    if ($result -and $result.Success) {
        # Clear and show success
        Clear-Host
        Write-Host ""
        Write-Host "══════════════════════════════════════════" -ForegroundColor Green
        Write-Host "        ✅ AUTHKEY EXTRACTED!            " -ForegroundColor White -BackgroundColor DarkGreen
        Write-Host "══════════════════════════════════════════" -ForegroundColor Green
        Write-Host ""
        Write-Host "Region: $($result.Region)" -ForegroundColor Cyan
        Write-Host "Time: $($result.Timestamp)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "══════════════════════════════════════════" -ForegroundColor Green
        Write-Host "🔑 Your AuthKey:" -ForegroundColor Yellow
        Write-Host "══════════════════════════════════════════" -ForegroundColor Green
        Write-Host ""
        Write-Host $result.AuthKey -ForegroundColor White
        Write-Host ""
        Write-Host "══════════════════════════════════════════" -ForegroundColor Green
        
        # Copy to clipboard
        Set-Clipboard -Value $result.AuthKey
        Write-Host "📋 Copied to clipboard!" -ForegroundColor Green
        Write-Host ""
        
    } else {
        Write-Host ""
        Write-Host "❌ Failed to extract authkey" -ForegroundColor Red
        Write-Host ""
        Write-Host "Make sure to:" -ForegroundColor Yellow
        Write-Host "1. Open Genshin Impact" -ForegroundColor Gray
        Write-Host "2. Click Wish icon" -ForegroundColor Gray
        Write-Host "3. Open wish history" -ForegroundColor Gray
        Write-Host "4. Wait 10 seconds" -ForegroundColor Gray
    }
    
} catch {
    Write-Host ""
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
}

# Wait before exit
Write-Host ""
Write-Host "Press Enter to exit..." -NoNewline
$null = Read-Host
