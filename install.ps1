# AI Workflow - 설치 스크립트 (Windows)
# ~/.claude/commands/ 에 커맨드 파일을 복사합니다.

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$targetDir = Join-Path $env:USERPROFILE ".claude\commands"

if (-not (Test-Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
}

Get-ChildItem "$scriptDir\commands\*.md" | ForEach-Object {
    Copy-Item $_.FullName -Destination $targetDir -Force
    Write-Host "설치됨: $targetDir\$($_.Name)"
}

Write-Host ""
Write-Host "설치 완료. Claude Code에서 /gen-api-tests 로 사용하세요."
