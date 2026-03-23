<# 
  Invoke-GooglePhotosAppCleanup.ps1
  ---------------------------------
  - OAuth (Installed App + PKCE) in-browser on first run; securely stores refresh token.
  - Lists media your app can access.
  - Optionally removes those items from an app-created album.
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$ClientId,

  [string]$ClientSecret,

  [string]$StatePath = "$env:APPDATA\GPhotos\oauth-state.json",

  [switch]$ExportCsv,
  [string]$CsvPath = ".\gphotos_appcreated_media.csv",

  [switch]$RemoveFromAlbum,
  [string]$AlbumId,

  [switch]$VerboseLog
)

$ErrorActionPreference = "Stop"
$OAuthTokenEndpoint = "https://oauth2.googleapis.com/token"
$AuthBase = "https://accounts.google.com/o/oauth2/v2/auth"
$PhotosApiBase = "https://photoslibrary.googleapis.com/v1"
$Scopes = @(
  "https://www.googleapis.com/auth/photoslibrary.readonly.appcreateddata",
  "https://www.googleapis.com/auth/photoslibrary.edit.appcreateddata"
) -join " "

function Write-Log([string]$Message) {
  if ($VerboseLog) {
    Write-Host "[GPhotos] $Message"
  }
}

function Save-SecretJson {
  param([string]$Path, [hashtable]$Data)

  $directory = Split-Path -Parent $Path
  if (-not (Test-Path $directory)) {
    New-Item -ItemType Directory -Path $directory | Out-Null
  }

  $json = $Data | ConvertTo-Json -Depth 5
  $secure = ConvertTo-SecureString -String $json -AsPlainText -Force
  $encrypted = $secure | ConvertFrom-SecureString
  Set-Content -Path $Path -Value $encrypted -Encoding UTF8
}

function Load-SecretJson {
  param([string]$Path)

  if (-not (Test-Path $Path)) {
    return $null
  }

  try {
    $encrypted = Get-Content -Path $Path -Raw -Encoding UTF8
    $secure = ConvertTo-SecureString $encrypted
    $json = [System.Net.NetworkCredential]::new("", $secure).Password
    if ([string]::IsNullOrWhiteSpace($json)) {
      return $null
    }
    return ConvertFrom-Json -InputObject $json
  }
  catch {
    return $null
  }
}

Add-Type -AssemblyName System.Web

function UrlEncode($Value) {
  [System.Web.HttpUtility]::UrlEncode($Value)
}

function New-CodeVerifier {
  $pool = (48..57) + (65..90) + (97..122) + 45,46,95,126
  $chars = New-Object char[] 64
  for ($i = 0; $i -lt 64; $i++) {
    $chars[$i] = [char]($pool | Get-Random)
  }
  [string]::Concat($chars)
}

function ConvertTo-Base64Url([byte[]]$Bytes) {
  [Convert]::ToBase64String($Bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
}

function New-CodeChallenge([string]$Verifier) {
  $sha = [System.Security.Cryptography.SHA256]::Create()
  ConvertTo-Base64Url($sha.ComputeHash([Text.Encoding]::ASCII.GetBytes($Verifier)))
}

function Get-OrCreate-RefreshToken {
  $state = Load-SecretJson -Path $StatePath
  if ($state -and $state.refresh_token) {
    Write-Log "Loaded encrypted refresh token."
    return $state.refresh_token
  }

  $port = Get-Random -Minimum 49152 -Maximum 65535
  $redirectUri = "http://127.0.0.1:$port/"
  $listener = New-Object System.Net.HttpListener
  $listener.Prefixes.Add($redirectUri)
  $listener.Start()

  $verifier = New-CodeVerifier
  $challenge = New-CodeChallenge -Verifier $verifier
  $authParams = @{
    client_id              = $ClientId
    redirect_uri           = $redirectUri
    response_type          = "code"
    scope                  = $Scopes
    access_type            = "offline"
    prompt                 = "consent"
    include_granted_scopes = "true"
    code_challenge         = $challenge
    code_challenge_method  = "S256"
  }

  $authUrl = "$AuthBase?" + ($authParams.Keys | ForEach-Object {
    "$(UrlEncode $_)=$(UrlEncode $authParams[$_])"
  } -join "&")

  Start-Process $authUrl
  $context = $listener.GetContext()
  $code = $context.Request.QueryString["code"]

  $responseHtml = "<html><body><h2>Authorization complete.</h2>You can close this window.</body></html>"
  $buffer = [Text.Encoding]::UTF8.GetBytes($responseHtml)
  $context.Response.ContentLength64 = $buffer.Length
  $context.Response.OutputStream.Write($buffer, 0, $buffer.Length)
  $context.Response.OutputStream.Close()
  $listener.Stop()

  if (-not $code) {
    throw "OAuth flow failed: no authorization code was returned."
  }

  $tokenBody = @{
    client_id     = $ClientId
    code          = $code
    code_verifier = $verifier
    redirect_uri  = $redirectUri
    grant_type    = "authorization_code"
  }

  if ($ClientSecret) {
    $tokenBody.client_secret = $ClientSecret
  }

  $token = Invoke-RestMethod -Method Post -Uri $OAuthTokenEndpoint -Body $tokenBody
  if (-not $token.refresh_token) {
    throw "OAuth succeeded, but no refresh token was returned."
  }

  Save-SecretJson -Path $StatePath -Data @{ refresh_token = $token.refresh_token }
  return $token.refresh_token
}

function Get-AccessToken([string]$RefreshToken) {
  $body = @{
    client_id     = $ClientId
    grant_type    = "refresh_token"
    refresh_token = $RefreshToken
  }

  if ($ClientSecret) {
    $body.client_secret = $ClientSecret
  }

  $response = Invoke-RestMethod -Method Post -Uri $OAuthTokenEndpoint -Body $body
  if (-not $response.access_token) {
    throw "Failed to obtain an access token."
  }

  $response.access_token
}

function Invoke-GooglePhotosApi {
  param(
    [Parameter(Mandatory = $true)]
    [string]$AccessToken,

    [Parameter(Mandatory = $true)]
    [string]$Method,

    [Parameter(Mandatory = $true)]
    [string]$Uri,

    [object]$Body
  )

  $headers = @{ Authorization = "Bearer $AccessToken" }
  $attempt = 0
  $maxAttempts = 5
  $delaySeconds = 1

  while ($true) {
    try {
      if ($Body) {
        return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $headers -ContentType "application/json" -Body ($Body | ConvertTo-Json -Depth 6)
      }

      return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $headers
    }
    catch {
      $attempt++
      $statusCode = $null
      if ($_.Exception -and $_.Exception.Response) {
        try { $statusCode = $_.Exception.Response.StatusCode.value__ } catch {}
      }

      if ($attempt -lt $maxAttempts -and ($statusCode -eq 429 -or $statusCode -ge 500)) {
        Start-Sleep -Seconds $delaySeconds
        $delaySeconds = [Math]::Min($delaySeconds * 2, 16)
      }
      else {
        throw
      }
    }
  }
}

function Get-GooglePhotosAppCreatedItems {
  param([Parameter(Mandatory = $true)][string]$AccessToken)

  $items = New-Object System.Collections.Generic.List[object]
  $pageToken = $null
  do {
    $uri = "$PhotosApiBase/mediaItems?pageSize=100" + ($(if ($pageToken) { "&pageToken=$pageToken" } else { "" }))
    $response = Invoke-GooglePhotosApi -AccessToken $AccessToken -Method Get -Uri $uri
    if ($response.mediaItems) {
      $response.mediaItems | ForEach-Object { $items.Add($_) }
    }
    $pageToken = $response.nextPageToken
  } while ($pageToken)

  ,$items.ToArray()
}

function Remove-GooglePhotosItemsFromAlbum {
  param(
    [Parameter(Mandatory = $true)][string]$AccessToken,
    [Parameter(Mandatory = $true)][string]$AlbumId,
    [Parameter(Mandatory = $true)][string[]]$MediaItemIds
  )

  $uri = "$PhotosApiBase/albums/$AlbumId:batchRemoveMediaItems"
  $batchSize = 50

  for ($i = 0; $i -lt $MediaItemIds.Count; $i += $batchSize) {
    $end = [Math]::Min($i + $batchSize - 1, $MediaItemIds.Count - 1)
    $chunk = $MediaItemIds[$i..$end]
    $body = @{ mediaItemIds = $chunk }
    Invoke-GooglePhotosApi -AccessToken $AccessToken -Method Post -Uri $uri -Body $body | Out-Null
  }
}

try {
  if ($RemoveFromAlbum -and [string]::IsNullOrWhiteSpace($AlbumId)) {
    throw "-AlbumId is required when using -RemoveFromAlbum."
  }

  $refreshToken = Get-OrCreate-RefreshToken
  $accessToken = Get-AccessToken -RefreshToken $refreshToken
  $items = Get-GooglePhotosAppCreatedItems -AccessToken $accessToken

  Write-Host ("Found {0} app-created item(s)." -f $items.Count)

  if ($ExportCsv) {
    $items |
      Select-Object id, filename, mimeType, productUrl, mediaMetadata |
      Export-Csv -NoTypeInformation -Path $CsvPath
  }

  if ($RemoveFromAlbum -and $items.Count -gt 0) {
    $ids = $items | ForEach-Object { $_.id } | Where-Object { $_ }
    Remove-GooglePhotosItemsFromAlbum -AccessToken $accessToken -AlbumId $AlbumId -MediaItemIds $ids
    Write-Host "Items removed from album."
  }
}
catch {
  Write-Error $_
  exit 1
}
