param(
    [string]$DevEcoPath = 'E:\DevEco Studio',
    [switch]$ConfigureVision,
    [string]$VisionModel,
    [string]$VisionBaseUrl
)

$ErrorActionPreference = 'Stop'
$node = Join-Path $DevEcoPath 'tools\node\node.exe'
$server = Join-Path $PSScriptRoot '..\mock\server.cjs'

if (-not $ConfigureVision) {
    & $node $server
    exit $LASTEXITCODE
}

if (-not $VisionModel) { $VisionModel = Read-Host 'Vision model name' }
$VisionModel = $VisionModel.Trim()
if (-not $VisionModel) { throw 'Enter a model name that supports image input and JSON output.' }

if (-not $VisionBaseUrl) {
    $VisionBaseUrl = Read-Host 'API base URL (Enter for OpenAI https://api.openai.com/v1)'
}
$VisionBaseUrl = $VisionBaseUrl.Trim()
if (-not $VisionBaseUrl) { $VisionBaseUrl = 'https://api.openai.com/v1' }
$endpoint = $null
if (-not [Uri]::TryCreate($VisionBaseUrl, [UriKind]::Absolute, [ref]$endpoint) -or
    ($endpoint.Scheme -ne 'https' -and
        ($endpoint.Scheme -ne 'http' -or $endpoint.Host -notin @('localhost', '127.0.0.1'))) -or
    $endpoint.UserInfo -or $endpoint.Query -or $endpoint.Fragment -or
    $endpoint.AbsolutePath.TrimEnd('/').EndsWith('/chat/completions')) {
    throw 'Enter a base URL such as https://api.openai.com/v1, without credentials or /chat/completions.'
}

$oldKey = $env:CAMPUS_VISION_API_KEY
$oldModel = $env:CAMPUS_VISION_MODEL
$oldBaseUrl = $env:CAMPUS_VISION_BASE_URL
$secret = Read-Host 'API key (hidden input)' -AsSecureString
try {
    if (-not $secret.Length) { throw 'The API key is empty.' }
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret)
    try {
        $env:CAMPUS_VISION_API_KEY = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer).Trim()
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
    }
    if (-not $env:CAMPUS_VISION_API_KEY) { throw 'The API key is empty.' }
    $env:CAMPUS_VISION_MODEL = $VisionModel
    $env:CAMPUS_VISION_BASE_URL = $VisionBaseUrl
    & $node $server
    $code = $LASTEXITCODE
} finally {
    $secret.Dispose()
    $env:CAMPUS_VISION_API_KEY = $oldKey
    $env:CAMPUS_VISION_MODEL = $oldModel
    $env:CAMPUS_VISION_BASE_URL = $oldBaseUrl
}
exit $code
