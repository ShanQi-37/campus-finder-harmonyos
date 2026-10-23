param([string]$DevEcoPath = 'E:\DevEco Studio')
$ErrorActionPreference = 'Stop'
$projectPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$nodePath = Join-Path $DevEcoPath 'tools\node\node.exe'
$hvigorPath = Join-Path $DevEcoPath 'tools\hvigor\bin\hvigorw.js'
$env:DEVECO_SDK_HOME = Join-Path $DevEcoPath 'sdk'
$env:JAVA_HOME = Join-Path $DevEcoPath 'jbr'
$env:NODE_HOME = Join-Path $DevEcoPath 'tools\node'
$env:Path = "$env:NODE_HOME;$env:JAVA_HOME\bin;$env:Path"
$buildPath = $projectPath
# Hvigor 禁止工程路径含中文。保留原始材料，在临时英文目录构建并拷回 HAP。
if ($projectPath -match '[^\x00-\x7F]') {
  $buildPath = Join-Path ([IO.Path]::GetTempPath()) ('CampusFinder-' + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $buildPath -Force | Out-Null
  foreach ($item in @('AppScope', 'entry', 'hvigor', 'hvigorfile.ts', 'build-profile.json5', 'oh-package.json5')) {
    if ($item -eq 'entry') {
      $entryDest = Join-Path $buildPath 'entry'
      New-Item -ItemType Directory -Path $entryDest -Force | Out-Null
      foreach ($entryItem in @('src', 'build-profile.json5', 'oh-package.json5', 'hvigorfile.ts')) {
        Copy-Item -LiteralPath (Join-Path $projectPath "entry\$entryItem") -Destination $entryDest -Recurse -Force
      }
    } else {
      Copy-Item -LiteralPath (Join-Path $projectPath $item) -Destination $buildPath -Recurse -Force
    }
  }
  Write-Host "中文路径兼容构建目录：$buildPath"
}
Push-Location -LiteralPath $buildPath
try {
  & $nodePath $hvigorPath --mode module -p product=default -p module=entry@default -p buildMode=debug assembleHap --no-daemon
  if ($LASTEXITCODE -ne 0) { throw "编译失败，退出码 $LASTEXITCODE" }
  if ($buildPath -ne $projectPath) {
    $outputPath = Join-Path $projectPath 'outputs'
    New-Item -ItemType Directory -Force -Path $outputPath | Out-Null
    Get-ChildItem -LiteralPath (Join-Path $buildPath 'entry\build\default\outputs\default') -Filter '*.hap' |
      Copy-Item -Destination $outputPath -Force
    Write-Host "HAP 已保存到 $outputPath"
  }
} finally { Pop-Location }
