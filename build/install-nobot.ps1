# NoBotStarter 独立安装脚本
#
# 作用：开房间不补 Bot，点「开始」直接开局
# 特点：独立、不依赖 PatchManager、不改标题、可单独分发
#
# 用法:
#   .\install-nobot.ps1                     安装（自动找游戏目录）
#   .\install-nobot.ps1 -GameDir "D:\..."   指定游戏目录
#   .\install-nobot.ps1 -Restore            还原原版
#   .\install-nobot.ps1 -Status             只看状态
#   .\install-nobot.ps1 -NoLaunch           装完不启动

param(
    [string]$GameDir = "",
    [switch]$Restore,
    [switch]$Status,
    [switch]$NoLaunch
)

$ErrorActionPreference = "Stop"

$HERE = $PSScriptRoot
$REL = "AstralParty_CN_Data\com.unity.addressables\AssetBundles\57a198703b66364d5420d39c0d251747\3486f99276eba77677d4880fd8d32918"
$PYTHON   = "python"
$TOOLS    = "<旧 Extra 目录>\tools"
$DLLPATCH = Join-Path $TOOLS "dllpatch\src\bin\Release\net9.0\dllpatch.exe"
$REFLIVE  = "<本地项目目录>\work\live_refs\AstralParty.Runtime.dll"
$WORK     = [System.IO.Path]::GetFullPath((Join-Path $TOOLS "..\work\nobot_standalone"))

$PATCH_JSON = Join-Path $HERE "nobot.patch.json"
$PACK_PY    = Join-Path $HERE "pack_bundle.py"

function Step($s) { Write-Host "  $s" }
function Fail($s) { Write-Host "  [!] $s" -ForegroundColor Red; exit 1 }
function OK($s)   { Write-Host "  [OK] $s" -ForegroundColor Green }

function Find-GameDir {
    $candidates = @(
        "D:\steam\steamapps\common\Astral Party\8vJXn6CN",
        "D:\Steam\steamapps\common\Astral Party\8vJXn6CN",
        "C:\Program Files (x86)\Steam\steamapps\common\Astral Party\8vJXn6CN",
        "D:\SteamLibrary\steamapps\common\Astral Party\8vJXn6CN",
        "E:\SteamLibrary\steamapps\common\Astral Party\8vJXn6CN"
    )
    foreach ($c in $candidates) {
        if (Test-Path (Join-Path $c "AstralParty_CN.exe")) { return $c }
    }
    $p = Get-Process AstralParty_CN -ErrorAction SilentlyContinue
    if ($p) { return (Split-Path $p.Path -Parent) }
    return $null
}

if (-not $GameDir) {
    $GameDir = Find-GameDir
    if (-not $GameDir) {
        Write-Host "找不到游戏目录，请用 -GameDir 指定" -ForegroundColor Red
        exit 1
    }
}

$live  = Join-Path $GameDir "$REL\__data"
$orig  = "$live.apa-orig"
$exDir = Join-Path $GameDir "AstralPartyExtra"

Write-Host ""
Write-Host "=== NoBotStarter ==="
Write-Host "游戏目录: $GameDir"
Write-Host ""

if (-not (Test-Path $live)) { Fail "找不到 hotfix bundle: $live" }

if ($Status) {
    Write-Host "状态:"
    Step ("hotfix bundle : " + (Get-Item $live).Length + " 字节")
    if (Test-Path $orig) { Step ("原版备份     : " + (Get-Item $orig).Length + " 字节") }
    else { Step "原版备份     : 无" }
    Step ("SHA256       : " + (Get-FileHash $live -Algorithm SHA256).Hash.Substring(0,16))
    $ini = Join-Path $exDir "nobot.ini"
    if (Test-Path $ini) { Step ("nobot.ini    : " + ((Get-Content $ini) -join " | ")) }
    else { Step "nobot.ini    : 无" }
    exit 0
}

if ($Restore) {
    Write-Host "[1/3] 关闭游戏"
    Get-Process AstralParty_CN -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 3
    Step "已关闭"

    Write-Host "[2/3] 检查备份"
    if (-not (Test-Path $orig)) { Fail "没有原版备份: $orig" }
    Step ((Get-Item $orig).Length.ToString() + " 字节")

    Write-Host "[3/3] 还原"
    Copy-Item $orig $live -Force
    if (Test-Path $exDir) { Copy-Item $orig (Join-Path $exDir "hotfix__data") -Force }
    Step ("已还原 " + (Get-Item $live).Length + " 字节")
    OK "还原完成"
    exit 0
}

Write-Host "[1/6] 检查环境"
if (-not (Test-Path $PYTHON))    { Fail "找不到 Python: $PYTHON" }
if (-not (Test-Path $DLLPATCH))  { Fail "找不到 dllpatch: $DLLPATCH" }
if (-not (Test-Path $REFLIVE))   { Fail "找不到参考 DLL: $REFLIVE" }
if (-not (Test-Path $PATCH_JSON)){ Fail "找不到补丁定义: $PATCH_JSON" }
if (-not (Test-Path $PACK_PY))   { Fail "找不到打包脚本: $PACK_PY" }
Step "环境 OK"

Write-Host "[2/6] 关闭游戏"
$procs = Get-Process AstralParty_CN -ErrorAction SilentlyContinue
if ($procs) {
    $procs | Stop-Process -Force
    for ($i = 0; $i -lt 20; $i++) {
        Start-Sleep -Milliseconds 250
        if (-not (Get-Process AstralParty_CN -ErrorAction SilentlyContinue)) { break }
    }
    Step "已关闭"
} else {
    Step "游戏未运行"
}

Write-Host "[3/6] 备份原版"
if (-not (Test-Path $orig)) {
    Copy-Item $live $orig -Force
    Step ("已备份 (" + (Get-Item $orig).Length + " 字节)")
} else {
    Step ("已有备份 (" + (Get-Item $orig).Length + " 字节)")
}

Write-Host "[4/6] 打补丁"
New-Item -ItemType Directory $WORK -Force | Out-Null
$patchedDll = Join-Path $WORK "AstralParty.Runtime.dll"
if (Test-Path $patchedDll) { Remove-Item $patchedDll -Force }

$out = & $DLLPATCH apply $REFLIVE $patchedDll $PATCH_JSON 2>&1 | Out-String
foreach ($line in ($out -split "`n")) {
    $t = $line.Trim()
    if ($t -and ($t -match "ConstSwap|wrote|FATAL|not found")) { Step $t }
}
if ($out -match "FATAL") { Fail "打补丁失败" }
if (-not (Test-Path $patchedDll)) { Fail "补丁输出不存在" }

Write-Host "[5/6] 打包 bundle"
$outBundle = Join-Path $WORK "nobot.hotfix__data"
if (Test-Path $outBundle) { Remove-Item $outBundle -Force }
$pyOut = & $PYTHON -X utf8 $PACK_PY $TOOLS $orig $patchedDll $outBundle 2>&1 | Out-String
foreach ($line in ($pyOut -split "`n")) {
    $t = $line.Trim()
    if ($t -and ($t -match "ok |Error|Traceback")) { Step $t }
}
if (-not (Test-Path $outBundle)) { Fail "打包失败" }
Step ("生成 " + (Get-Item $outBundle).Length + " 字节")

Write-Host "[6/6] 安装"
Copy-Item $outBundle $live -Force
if (-not (Test-Path $exDir)) { New-Item -ItemType Directory $exDir -Force | Out-Null }
Copy-Item $outBundle (Join-Path $exDir "hotfix__data") -Force
[System.IO.File]::WriteAllLines((Join-Path $exDir "nobot.ini"),
    @("[NoBotStarter]", "enabled=1"), [System.Text.Encoding]::ASCII)

$h1 = (Get-FileHash $live -Algorithm SHA256).Hash
$h2 = (Get-FileHash $outBundle -Algorithm SHA256).Hash
if ($h1 -ne $h2) { Fail "校验失败: $($h1.Substring(0,12)) != $($h2.Substring(0,12))" }
Step ("SHA256 " + $h1.Substring(0,16))
OK "安装完成"

if (-not $NoLaunch) {
    Write-Host ""
    Write-Host "启动游戏验证..."
    Start-Process -FilePath (Join-Path $GameDir "AstralParty_CN.exe") -WorkingDirectory $GameDir
    Start-Sleep -Seconds 25
    $modLog = Join-Path $exDir "apa_mod.log"
    if (Test-Path $modLog) {
        Write-Host "=== mod 日志 ==="
        Get-Content $modLog -Encoding UTF8 -TotalCount 3 | ForEach-Object { Write-Host "  $_" }
    }
}

Write-Host ""
Write-Host "完成。开房间后点「开始」应该直接开局，不补 Bot。"
Write-Host "还原: .\install-nobot.ps1 -Restore"