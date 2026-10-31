param(
    [string]$Payload = '',
    [string]$VcVars  = 'D:\vsstudios\VC\Auxiliary\Build\vcvars64.bat',
    [switch]$Test
)

$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot

if (-not (Test-Path -LiteralPath $VcVars))  { throw "找不到 vcvars64.bat: $VcVars" }

# 没给 -Payload 时，从 dist\hid.dll 尾部提取内嵌补丁（保持单文件可复现）
if (-not $Payload) {
    $distDll = Join-Path $here '..\..\dist\hid.dll'
    if (-not (Test-Path -LiteralPath $distDll)) { throw "缺少 -Payload，且找不到 dist\hid.dll" }
    $b = [System.IO.File]::ReadAllBytes($distDll)
    if ($b.Length -lt 32) { throw "dist\hid.dll 太小" }
    $footer = $b[($b.Length - 20)..($b.Length - 1)]
    if ([System.Text.Encoding]::ASCII.GetString($footer, 0, 4) -ne 'NBP1') { throw "dist\hid.dll 里没有内嵌补丁" }
    $off = [BitConverter]::ToUInt64($footer, 4)
    $len = [BitConverter]::ToUInt64($footer, 12)
    $tmp  = Join-Path $env:TEMP 'nobot-payload.bin'
    [System.IO.File]::WriteAllBytes($tmp, $b[$off..($off + $len - 1)])
    $Payload = $tmp
    Write-Host "从 dist\hid.dll 提取内嵌补丁: $len 字节"
}

if (-not (Test-Path -LiteralPath $Payload)) { throw "找不到补丁包: $Payload" }

Push-Location $here
try {
    # 1) 生成导出表 + thunk
    $py = 'python'
    if (-not (Test-Path -LiteralPath $py)) { $py = 'python' }
    & $py gen.py | Out-Null

    # 2) 编译
    $srcs = @(
        'nobot.c',
        'minhook\src\buffer.c', 'minhook\src\hook.c', 'minhook\src\trampoline.c',
        'minhook\src\hde\hde32.c', 'minhook\src\hde\hde64.c'
    ) -join ' '
    $cmd = "ml64 /nologo /c thunks.asm && cl /nologo /LD /O2 /MT /utf-8 /D_CRT_SECURE_NO_WARNINGS /I . /I minhook\include /I minhook\src /I minhook\src\hde $srcs thunks.obj /Fe:hid.dll /link /DEF:exports.def /MACHINE:X64 /SUBSYSTEM:WINDOWS user32.lib"
    cmd /c "`"$VcVars`" >nul && $cmd"
    if ($LASTEXITCODE -ne 0) { throw "编译失败 ($LASTEXITCODE)" }

    # 3) 尾部追加补丁包（NBP1 + offset + size）
    $dllPath = Join-Path $here 'hid.dll'
    $off = (Get-Item -LiteralPath $dllPath).Length
    if ($off -le 0) { throw "hid.dll 大小异常: $off" }
    $payloadBytes = [System.IO.File]::ReadAllBytes($Payload)
    $footer = [System.Text.Encoding]::ASCII.GetBytes('NBP1') +
              [BitConverter]::GetBytes([uint64]$off) +
              [BitConverter]::GetBytes([uint64]$payloadBytes.Length)
    $fs = [System.IO.File]::Open($dllPath, 'Append')
    try {
        $fs.Write($payloadBytes, 0, $payloadBytes.Length)
        $fs.Write($footer, 0, $footer.Length)
    } finally { $fs.Close() }

    $final = Get-Item $dllPath
    Write-Host ("hid.dll 构建完成: {0:N1} MB" -f ($final.Length / 1MB))

    # 4) 可选：测试程序
    if ($Test) {
        $tcmd = "cl /nologo /O2 /MT /utf-8 /D_CRT_SECURE_NO_WARNINGS test.c /Fe:test.exe user32.lib"
        cmd /c "`"$VcVars`" >nul && $tcmd"
        if ($LASTEXITCODE -ne 0) { throw "测试程序编译失败 ($LASTEXITCODE)" }
        Write-Host 'test.exe 构建完成'
    }
} finally {
    Pop-Location
}
