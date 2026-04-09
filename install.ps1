# AI Workflow - 설치 스크립트 (Windows)
# ~/.claude/ 에 커맨드와 에이전트를 복사합니다.

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$claudeDir = Join-Path $env:USERPROFILE ".claude"

# Commands 설치
$cmdDir = Join-Path $claudeDir "commands"
if (-not (Test-Path $cmdDir)) {
    New-Item -ItemType Directory -Path $cmdDir -Force | Out-Null
}
Get-ChildItem "$scriptDir\commands\*.md" | ForEach-Object {
    Copy-Item $_.FullName -Destination $cmdDir -Force
    Write-Host "커맨드 설치됨: $cmdDir\$($_.Name)"
}

# Agents 설치
$agentDir = Join-Path $claudeDir "agents"
if (-not (Test-Path $agentDir)) {
    New-Item -ItemType Directory -Path $agentDir -Force | Out-Null
}
Get-ChildItem "$scriptDir\agents\*.md" | ForEach-Object {
    Copy-Item $_.FullName -Destination $agentDir -Force
    Write-Host "에이전트 설치됨: $agentDir\$($_.Name)"
}

Write-Host ""
Write-Host "설치 완료. Claude Code에서 /gen-api-tests 로 사용하세요."
