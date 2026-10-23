param([string]$DevEcoPath = 'E:\DevEco Studio')
$ErrorActionPreference = 'Stop'
& (Join-Path $DevEcoPath 'tools\node\node.exe') (Join-Path $PSScriptRoot '..\mock\server.cjs')
