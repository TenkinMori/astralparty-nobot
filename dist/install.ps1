param([switch]$Restore)
$ErrorActionPreference = "Stop"
$HERE = $PSScriptRoot
$REL = "AstralParty_CN_Data\com.unity.addressables\AssetBundles"

function Find-Game {
    $c = @(
        "D:\steam\steamapps\common\Astral Party\8vJXn6CN",
        "D:\Steam\steamapps\common\Astral Party\8vJXn6CN",
        "C:\Program Files (x86)\Steam\steamapps\common\Astral Party\8vJXn6CN",
        "D:\SteamLibrary\steamapps\common\Astral Party\8vJXn6CN",
        "E:\SteamLibrary\steamapps\common\Astral Party\8vJXn6CN"
    )
    foreach ($x in $c) { if (Test-Path (Join-Path $x "AstralParty_CN.exe")) { return $x } }
    $p = Get-Process AstralParty_CN -ErrorAction SilentlyContinue
    if ($p) { return (Split-Path $p.Path -Parent) }
    return $null
}

$game = Find-Game
if (-not $game) { Write-Host "找不到游戏目录" -ForegroundColor Red; exit 1 }

Write-Host ""
Write-Host "游戏目录: $game"
Write-Host ""

Get-Process AstralParty_CN -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 3

if ($Restore) {
    $hidBak = Join-Path $game "hid.dll.nobot-bak"
    if (Test-Path $hidBak) {
        Copy-Item $hidBak (Join-Path $game "hid.dll") -Force
        Write-Host "已还原 hid.dll" -ForegroundColor Green
    } else {
        Write-Host "没有 hid.dll 备份，请用 Steam 验证完整性" -ForegroundColor Yellow
    }
    $ex = Join-Path $game "AstralPartyExtra"
    if (Test-Path $ex) {
        Remove-Item (Join-Path $ex "hotfix__data") -Force -ErrorAction SilentlyContinue
        Remove-Item (Join-Path $ex "live.txt") -Force -ErrorAction SilentlyContinue
    }
    Write-Host "已移除补丁包" -ForegroundColor Green
    exit 0
}

# 1. 备份并安装 hid.dll
$hidDst = Join-Path $game "hid.dll"
$hidBak = "$hidDst.nobot-bak"
if (-not (Test-Path $hidBak)) {
    if (Test-Path $hidDst) { Copy-Item $hidDst $hidBak -Force }
}
Copy-Item (Join-Path $HERE "hid.dll") $hidDst -Force
Write-Host "  hid.dll 已安装" 

# 2. hid_orig.dll
Copy-Item (Join-Path $HERE "hid_orig.dll") (Join-Path $game "hid_orig.dll") -Force
Write-Host "  hid_orig.dll 已安装"

# 3. AstralPartyExtra
$exDst = Join-Path $game "AstralPartyExtra"
if (-not (Test-Path $exDst)) { New-Item -ItemType Directory $exDst -Force | Out-Null }
Copy-Item (Join-Path $HERE "AstralPartyExtra\hotfix__data") (Join-Path $exDst "hotfix__data") -Force
Write-Host "  hotfix__data 已安装"

# 4. live.txt：指向实际 hotfix bundle
$found = $null
$bundles = Join-Path $game "$REL"
if (Test-Path $bundles) {
    Get-ChildItem $bundles -Recurse -Filter "__data" -ErrorAction SilentlyContinue |
        Where-Object { $_.Length -gt 2000000 -and $_.Length -lt 33554432 } |
        Sort-Object Length -Descending | ForEach-Object {
            if (-not $found) {
                $fs = [System.IO.File]::OpenRead($_.FullName)
                $sig = New-Object byte[] 7
                $null = $fs.Read($sig, 0, 7)
                $fs.Close()
                if ([System.Text.Encoding]::ASCII.GetString($sig) -match "UnityFS") { $found = $_.FullName }
            }
        }
}
if ($found) {
    $orig = "$found.apa-orig"
    if (-not (Test-Path $orig)) { Copy-Item $found $orig -Force }
    [System.IO.File]::WriteAllLines((Join-Path $exDst "live.txt"), @($found, $orig), [System.Text.Encoding]::ASCII)
    Write-Host "  live.txt -> $found"
} else {
    Write-Host "  [!] 没找到 hotfix bundle（先运行一次游戏）" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "安装完成。启动游戏即可。" -ForegroundColor Green
Write-Host "还原: 运行 还原.bat"