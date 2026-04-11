# AI Workflow - 설치 스크립트 (Windows)
# ~/.claude/ 에 심링크를 생성합니다.
# 소스 수정 시 즉시 반영되며, 다른 프로젝트에서 수정해도 소스에 반영됩니다.
#
# 주의: Windows에서 심링크 생성은 관리자 권한 또는 개발자 모드가 필요합니다.
# 심링크 실패 시 자동으로 복사 방식으로 폴백합니다.

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$claudeDir = Join-Path $env:USERPROFILE ".claude"
$useSymlink = $true

# 심링크 가능 여부 테스트 (파일 심링크로 테스트)
$testLink = Join-Path $claudeDir ".symlink_test"
$testTarget = Join-Path $scriptDir "README.md"
try {
    if (Test-Path $testLink) { Remove-Item $testLink -Force }
    New-Item -ItemType SymbolicLink -Path $testLink -Target $testTarget -Force -ErrorAction Stop | Out-Null
    Remove-Item $testLink -Force
} catch {
    $useSymlink = $false
    Write-Host "심링크 생성 불가 — 복사 방식으로 설치합니다." -ForegroundColor Yellow
    Write-Host "(심링크를 원하면 '개발자 모드' 활성화 또는 관리자 권한으로 실행)" -ForegroundColor Yellow
    Write-Host ""
}

# Commands 설치
$cmdDir = Join-Path $claudeDir "commands"
if (!(Test-Path $cmdDir)) {
    New-Item -ItemType Directory -Path $cmdDir -Force | Out-Null
}
Get-ChildItem "$scriptDir\commands\*.md" | ForEach-Object {
    $target = Join-Path $cmdDir $_.Name
    if (Test-Path $target) { Remove-Item $target -Force }
    if ($useSymlink) {
        New-Item -ItemType SymbolicLink -Path $target -Target $_.FullName -Force | Out-Null
        Write-Host "커맨드 링크: $target"
    } else {
        Copy-Item $_.FullName -Destination $target -Force
        Write-Host "커맨드 복사: $target"
    }
}

# Agents 설치
$agentDir = Join-Path $claudeDir "agents"
if (!(Test-Path $agentDir)) {
    New-Item -ItemType Directory -Path $agentDir -Force | Out-Null
}
Get-ChildItem "$scriptDir\agents\*.md" | ForEach-Object {
    $target = Join-Path $agentDir $_.Name
    if (Test-Path $target) { Remove-Item $target -Force }
    if ($useSymlink) {
        New-Item -ItemType SymbolicLink -Path $target -Target $_.FullName -Force | Out-Null
        Write-Host "에이전트 링크: $target"
    } else {
        Copy-Item $_.FullName -Destination $target -Force
        Write-Host "에이전트 복사: $target"
    }
}

Write-Host ""
if ($useSymlink) {
    Write-Host "설치 완료 (심링크 방식 — 소스 수정 시 즉시 반영)"
} else {
    Write-Host "설치 완료 (복사 방식 — 소스 수정 후 install.ps1 재실행 필요)"
}
Write-Host "  /start — 프로젝트 시작 (총괄 오케스트레이터)"
Write-Host "  /who   — 전문가 안내"
Write-Host "  /dev   — TDD 기반 개발"
Write-Host "  /qa    — 테스트 커버리지 구축"
