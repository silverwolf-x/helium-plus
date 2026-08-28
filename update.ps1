## update-body.ps1 — Helium portable self-updater (production engine)
## 由 update.cmd 载入；也可由测试直接调用（用 HELIUM_UPDATE_* 环境变量注入 mock）。
##
## 原则：
##   1. 只替换 App/ 与根目录版本标记；Data/、Cache/、update.*、其它根文件一律不动。
##   2. 新包先解压到 %TEMP% 校验，再同卷 staging 装入，旧 App 原子改名备份。
##   3. 任何一步失败都回滚旧 App 并保留旧版本标记；绝不把当前安装弄成半残状态。
##   4. 只关闭"本便携目录 App 下"的 chrome 进程，绝不动系统 Chrome。
##   5. 退出码：0 成功 / 1 用户取消 / 2 已是最新 / 3 网络·release·资产错误 /
##               4 校验(结构)错误 / 5 浏览器无法关闭 / 6 其他运行时错误(已回滚)

[CmdletBinding()]
param([switch]$CheckOnly)
$chk = $CheckOnly -or ($env:HUP_CHECK_ONLY -eq '1')

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
Add-Type -AssemblyName System.IO.Compression.FileSystem

$GITHUB_API  = 'https://api.github.com'
$DEFAULT_REPO = 'silverwolf-x/helium-plus'
$PREF_ARCH = switch ($env:PROCESSOR_ARCHITECTURE) { 'AMD64' { 'x64' }; 'ARM64' { 'arm64' }; default { '' } }
$repoArg = $null
if (-not $repoArg) { $repoArg = $env:HUP_REPO }
if (-not $repoArg) { $repoArg = $DEFAULT_REPO }
if ($repoArg -match '^https://github\.com/') { $repoArg = $repoArg.Substring(19).TrimEnd('/') }
if ($repoArg -notmatch '^[^/]+/[^/]+$') { throw ('无法解析 GitHub 仓库地址: ' + $repoArg) }
$Repo = $repoArg

$Root = $env:HUP_PACKAGE_ROOT
if (-not $Root) {
  $Root = $env:HUP_SCRIPT_DIR
  if (-not $Root) { throw '脚本目录未提供：请用 update.cmd 运行' }
}
if (-not (Test-Path -LiteralPath $Root -PathType Container)) { throw ('目录不存在: ' + $Root) }

function Log { param([string]$m) Write-Host $m }
function Fail { param([int]$code, [string]$m) Write-Host ('[!] ' + $m); exit $code }
function Confirm-Yes {
  param([string]$prompt)
  if ($env:HUP_SKIP_PROMPTS -eq '1') { return ($env:HUP_AUTO_ANSWER -ne 'no') }
  $a = Read-Host $prompt
  return ($a.Trim().ToLowerInvariant() -in @('y','yes'))
}
function Compare-Version {
  param([string]$a, [string]$b)
  $a = ($a -split '\+')[0]; $b = ($b -split '\+')[0]
  $pa = $a.Split('.'); $pb = $b.Split('.')
  $n = [Math]::Max($pa.Length, $pb.Length)
  for ($i=0; $i -lt $n; $i++) {
    $va = 0L; $vb = 0L
    if ($i -lt $pa.Length) { $va = [long]$pa[$i] }
    if ($i -lt $pb.Length) { $vb = [long]$pb[$i] }
    if ($va -gt $vb) { return 1 }
    if ($va -lt $vb) { return -1 }
  }
  return 0
}
function Convert-Tag { param([string]$t) if ($t.StartsWith('v')) { return $t.Substring(1) }; return $t }

# ---------- 1. 本地版本（根目录标记文件） ----------
$markers = @(Get-ChildItem -LiteralPath $Root -File -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -match '^\d+(\.\d+)*\+\d+(\.\d+)*$' } |
  Select-Object -ExpandProperty Name)
if (-not $markers) { Fail 4 ('未找到本地版本标记（根目录应有一个形如 0.15.7.1+1.18.2 的文件）。请确认 update.cmd 放在便携目录根目录。') }
if ($markers.Count -gt 1) { Fail 4 ('检测到多个本地版本标记，无法确认当前版本: ' + ($markers -join ', ')) }
$LocalTag = $markers[0]
Log ('本地版本 : ' + $LocalTag)

# ---------- 2. 最新 Release ----------
$apiUrl = $env:HUP_API_URL
if (-not $apiUrl) { $apiUrl = $GITHUB_API + '/repos/' + $Repo + '/releases/latest' }
Log ('更新源   : ' + $Repo)
if ($env:HUP_RELEASE_JSON_PATH) {
  $relJson = $env:HUP_RELEASE_JSON_PATH
  if (-not (Test-Path -LiteralPath $relJson)) { Fail 3 ('mock release 文件不存在: ' + $relJson) }
  $Release = Get-Content -LiteralPath $relJson -Raw -Encoding UTF8 | ConvertFrom-Json
} else {
  try { $Release = Invoke-RestMethod -Uri $apiUrl -Method Get -Headers @{ 'User-Agent' = 'helium-updater/1.0' } }
  catch { Fail 3 ('获取最新 release 失败: ' + $_.Exception.Message) }
}
if (-not $Release -or -not $Release.tag_name) { Fail 3 'release 响应缺少 tag_name（可能无 release 或被限流）' }
$LatestTag = Convert-Tag $Release.tag_name
Log ('最新版本 : ' + $LatestTag)

# ---------- 3. 选择资产 ----------
$Arch = $env:HUP_ARCH
if (-not $Arch) {
  if (-not $PREF_ARCH) { Fail 3 ('不支持的 CPU 架构: ' + $env:PROCESSOR_ARCHITECTURE) }
  $Arch = $PREF_ARCH
}
$AssetNames = @(
  'helium_' + $LatestTag + '_' + $Arch + '-windows.zip'
  'helium_' + $LatestTag + '_' + $Arch + '_windows.zip'
)
$Asset = @($Release.assets | Where-Object { $_.name -in $AssetNames })[0]
if ($Asset) { $AssetName = $Asset.name }
if (-not $Asset) { Fail 3 ('最新 release 中没有找到匹配资产: ' + ($AssetNames -join ' 或 ') + '（可用: ' + ((@($Release.assets.name) -join ', ')) + ')' ) }
Log ('匹配资产 : ' + $AssetName)

# ---------- 4. 版本比较 ----------
$cmp = Compare-Version $LocalTag $LatestTag
if ($cmp -ge 0) { Log ('本机已是最新（' + $LocalTag + '），无需更新。'); exit 2 }
if ($chk) { Log ('[检测] 本地 ' + $LocalTag + ' → 最新 ' + $LatestTag + '（仅检测，未下载未修改）'); exit 0 }
Log ('[更新] ' + $LocalTag + ' → ' + $LatestTag)

# ---------- 5. 确认下载 ----------
if (-not (Confirm-Yes ('发现新版本 ' + $LatestTag + '，是否下载并更新？(y/n)'))) { Fail 1 '用户取消下载。' }

# ---------- 6. 下载 + 解压 + 结构校验（不触碰当前安装） ----------
$workBase = Join-Path ([IO.Path]::GetTempPath()) ('helium_update_' + [guid]::NewGuid().ToString('N'))
try {
  if (-not (Test-Path -LiteralPath $workBase)) { [void](New-Item -ItemType Directory -Path $workBase -Force) }
} catch { Fail 6 ('创建临时目录失败: ' + $_.Exception.Message) }
$zipPath = Join-Path $workBase $AssetName
if ($env:HUP_ZIP_PATH) {
  Log ('使用本地压缩包: ' + $env:HUP_ZIP_PATH)
  if (-not (Test-Path -LiteralPath $env:HUP_ZIP_PATH)) { Fail 3 ('mock 压缩包不存在: ' + $env:HUP_ZIP_PATH) }
  Copy-Item -LiteralPath $env:HUP_ZIP_PATH -Destination $zipPath -Force
} else {
  Log ('下载中: ' + $Asset.browser_download_url)
  try { Invoke-WebRequest -Uri $Asset.browser_download_url -OutFile $zipPath -UseBasicParsing -Headers @{ 'User-Agent' = 'helium-updater/1.0' } }
  catch { Fail 3 ('下载失败: ' + $_.Exception.Message) }
}

$extractDir = Join-Path $workBase 'extract'
[void](New-Item -ItemType Directory -Path $extractDir -Force)
try {
  $zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
  try {
    $destFull = [IO.Path]::GetFullPath($extractDir)
    foreach ($entry in $zip.Entries) {
      $cand = [IO.Path]::GetFullPath((Join-Path $destFull $entry.FullName))
      if (-not $cand.StartsWith($destFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        Fail 4 ('压缩包含非法路径，已拒绝: ' + $entry.FullName)
      }
      if ($entry.FullName.EndsWith('/')) { [void](New-Item -ItemType Directory -Force -Path $cand); continue }
      $parent = Split-Path -Parent $cand
      if ($parent -and -not (Test-Path -LiteralPath $parent)) { [void](New-Item -ItemType Directory -Force -Path $parent) }
      [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $cand, $true)
    }
  } finally { $zip.Dispose() }
} catch { Fail 4 ('解压失败（压缩包可能损坏）: ' + $_.Exception.Message) }

# 定位包根：最浅的含 App\chrome.exe 的目录
$packageRoot = $null
foreach ($d in @(Get-ChildItem -LiteralPath $extractDir -Directory -Recurse -ErrorAction SilentlyContinue | Sort-Object { $_.FullName.Length })) {
  if (Test-Path -LiteralPath (Join-Path $d.FullName 'App\chrome.exe')) { $packageRoot = $d.FullName; break }
}
if (-not $packageRoot -and (Test-Path -LiteralPath (Join-Path $extractDir 'App\chrome.exe'))) { $packageRoot = $extractDir }
if (-not $packageRoot) { Fail 4 '压缩包内未找到 App\chrome.exe，结构不符合便携包。' }
$newAppSrc = Join-Path $packageRoot 'App'
foreach ($nf in @('chrome.exe','chrome++.ini','version.dll')) {
  if (-not (Test-Path -LiteralPath (Join-Path $newAppSrc $nf))) { Fail 4 ('新包缺少文件: ' + $nf) }
}
Log ('新包结构校验通过。')

# ---------- 7. 确认关闭浏览器（仅本便携目录下的 chrome） ----------
function Get-PortableChrome {
  $appBase = (Join-Path $Root 'App') + [IO.Path]::DirectorySeparatorChar
  return @(Get-Process -Name 'chrome' -ErrorAction SilentlyContinue | Where-Object {
    try { $_.Path -and $_.Path -like ($appBase + '*') } catch { $false }
  })
}
$procs = @(Get-PortableChrome)
if ($procs.Count -gt 0) {
  Log ('检测到 ' + $procs.Count + ' 个本便携浏览器进程。需要关闭后才能替换。')
  if (-not (Confirm-Yes ('是否关闭这些进程以继续更新？(y/n)'))) { Fail 5 '用户拒绝关闭浏览器，已退出。' }
  foreach ($p in $procs) { try { [void]$p.CloseMainWindow() } catch {}; Start-Sleep -Milliseconds 200 }
  $deadline = (Get-Date).AddSeconds(10)
  while ((@(Get-PortableChrome).Count -gt 0) -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 400 }
  $still = @(Get-PortableChrome)
  if ($still.Count -gt 0) {
    if (-not (Confirm-Yes ('仍有 ' + $still.Count + ' 个进程未退出，是否强制结束？(y/n)'))) { Fail 5 '浏览器仍在运行，已退出。' }
    foreach ($p in $still) { try { Stop-Process -Id $p.Id -Force -ErrorAction Stop } catch { Fail 5 ('无法强制结束进程 ' + $p.Id + ': ' + $_.Exception.Message) } }
    Start-Sleep -Seconds 2
    if (@(Get-PortableChrome).Count -gt 0) { Fail 5 '浏览器进程仍然存在，放弃更新。' }
  }
} else { Log '未检测到本便携浏览器进程。' }

# ---------- 8. 事务替换（同卷 staging + 原子 rename + 回滚） ----------
$appPath   = Join-Path $Root 'App'
$guid      = [guid]::NewGuid().ToString('N')
$staging   = Join-Path $Root ('.helium_update_stage_' + $guid)
$backup    = Join-Path $Root ('App.bak_' + $guid)
$rolledBack = $false
try {
  # 8.1 新 App 复制到同卷 staging（跨卷复制只发生在此，失败时旧 App 未动）
  [void](New-Item -ItemType Directory -Path $staging -Force)
  Copy-Item -LiteralPath $newAppSrc -Destination (Join-Path $staging 'App') -Recurse -Force
  foreach ($nf in @('chrome.exe','chrome++.ini','version.dll')) {
    if (-not (Test-Path -LiteralPath (Join-Path $staging ('App\' + $nf)))) { throw 'staging App 校验失败: ' + $nf }
  }
  # 8.2 旧 App 原子改名为备份
  if (Test-Path -LiteralPath $appPath) { Rename-Item -LiteralPath $appPath -NewName (Split-Path -Leaf $backup) }
  # 8.3 注入失败点（测试回滚）
  if ($env:HUP_INJECT_SWAP_FAIL -eq '1') { throw 'INJECTED_SWAP_FAILURE' }
  # 8.4 装入新 App
  Move-Item -LiteralPath (Join-Path $staging 'App') -Destination $appPath -Force
  # 8.5 再次校验
  foreach ($nf in @('chrome.exe','chrome++.ini','version.dll')) {
    if (-not (Test-Path -LiteralPath (Join-Path $appPath $nf))) { throw '装入后校验失败: ' + $nf }
  }
  # 8.6 版本标记：先写新，后删旧
  [void](New-Item -ItemType File -Path (Join-Path $Root $LatestTag) -Force)
  $oldMarker = Join-Path $Root $LocalTag
  if ($LocalTag -ne $LatestTag -and (Test-Path -LiteralPath $oldMarker)) { Remove-Item -LiteralPath $oldMarker -Force }
  # 8.7 收尾：清备份、清 staging
  if (Test-Path -LiteralPath $backup)  { Remove-Item -LiteralPath $backup -Recurse -Force }
  if (Test-Path -LiteralPath $staging) { Remove-Item -LiteralPath $staging -Recurse -Force }
  Log ('更新成功：' + $LocalTag + ' → ' + $LatestTag)
  exit 0
} catch {
  $rollbackErr = $_.Exception.Message
  Write-Host ('[!] 更新失败: ' + $rollbackErr)
  # 回滚：把新 App（若有）挪开，恢复旧 App 备份
  try {
    if (Test-Path -LiteralPath $appPath) {
      $failed = Join-Path $Root ('App.failed_' + $guid)
      Rename-Item -LiteralPath $appPath -NewName (Split-Path -Leaf $failed)
    }
    if (Test-Path -LiteralPath $backup) { Rename-Item -LiteralPath $backup -NewName 'App' }
    $newMarker = Join-Path $Root $LatestTag
    if (Test-Path -LiteralPath $newMarker) { Remove-Item -LiteralPath $newMarker -Force }
    if (Test-Path -LiteralPath $staging) { Remove-Item -LiteralPath $staging -Recurse -Force }
    $rolledBack = $true
    Log '已回滚到更新前的版本。'
  } catch {
    Write-Host ('[!] 回滚失败，请手动检查: ' + $_.Exception.Message)
  }
  if ($rollbackErr -like '*INJECTED*') { exit 6 }
  exit 6
}
