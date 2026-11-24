param(
    [ValidateRange(1, 65535)][int]$Port = 4524,
    [switch]$CheckText,
    [string]$PhotoPath
)

$ErrorActionPreference = 'Stop'
$base = "http://127.0.0.1:$Port"
$health = (Invoke-RestMethod -Uri "$base/health").data
if ($health.service -ne 'CampusFinder' -or $null -eq $health.ai) {
    throw 'Start the current CampusFinder Mock before running this check.'
}
$health.ai | Format-List
$headers = @{}
if ($CheckText -or $PhotoPath) {
    $credentials = @{ method = 'student'; account = '20260001'; password = 'campus123' } | ConvertTo-Json -Compress
    $session = (Invoke-RestMethod -Method Post -Uri "$base/api/auth/login" -ContentType 'application/json' -Body $credentials).data
    $headers.Authorization = 'Bearer ' + $session.token
}

try {
    if ($CheckText) {
        if (-not $health.ai.textConfigured) { throw 'Start the Mock with -ConfigureVision to test text parsing.' }
        $sample = @{ query = 'I lost a blue water bottle at the library yesterday.' } | ConvertTo-Json -Compress
        (Invoke-RestMethod -Method Post -Uri "$base/api/search/interpret" -Headers $headers -ContentType 'application/json' -Body $sample).data |
            Format-List
    }

    if ($PhotoPath) {
        if (-not $health.ai.imageConfigured) { throw 'Start the Mock with -ConfigureVision to test photo search.' }
        $photo = Get-Item -LiteralPath $PhotoPath
        if ($photo.PSIsContainer -or $photo.Extension -notin @('.jpg', '.jpeg', '.png') -or
            $photo.Length -lt 1 -or $photo.Length -gt 8MB) {
            throw 'Choose a nonempty JPEG or PNG file of at most 8 MiB.'
        }
        $result = (Invoke-RestMethod -Method Post -Uri "$base/api/media/search" -Headers $headers -ContentType 'application/octet-stream' -InFile $photo.FullName).data
        [pscustomobject]@{
            Object = $result.recognition.object
            Category = $result.recognition.category
            Features = $result.recognition.features -join ', '
            Candidates = @($result.matches).Count
        } | Format-List
    }
} finally {
    if ($headers.Authorization) {
        try { Invoke-RestMethod -Method Post -Uri "$base/api/auth/logout" -Headers $headers -ContentType 'application/json' -Body '{}' | Out-Null }
        catch { }
    }
}
