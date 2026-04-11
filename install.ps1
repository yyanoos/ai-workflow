# AI Workflow - 설치 스크립트 (Windows)
# ~/.claude/ 에 심링크를 생성합니다.
# 소스 수정 시 즉시 반영되며, 다른 프로젝트에서 수정해도 소스에 반영됩니다.
#
# 주의: Windows에서 심링크 생성은 관리자 권한 또는 개발자 모드가 필요합니다.
# 심링크 실패 시 자동으로 복사 방식으로 폴백합니다.
#
# 사용법:
#   .\install.ps1             설치
#   .\install.ps1 -Uninstall  제거

param(
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$claudeDir = Join-Path $env:USERPROFILE ".claude"

# --uninstall
if ($Uninstall) {
    Write-Host "AI Workflow 제거 중..."
    $removed = 0
    @("commands", "agents") | ForEach-Object {
        $dir = Join-Path $claudeDir $_
        Get-ChildItem "$scriptDir\$_\*.md" -ErrorAction SilentlyContinue | ForEach-Object {
            $target = Join-Path $dir $_.Name
            if (Test-Path $target) {
                Remove-Item $target -Force
                Write-Host "  제거: $target"
                $removed++
            }
        }
    }
    Write-Host ""
    Write-Host "제거 완료 ($removed 개 파일)"
    exit
}

$useSymlink = $true
$cmdCount = 0
$agentCount = 0

# 심링크 가능 여부 테스트 (파일 심링크로 테스트)
$testLink = Join-Path $claudeDir ".symlink_test"
$testTarget = Join-Path $scriptDir "README.md"
try {
    if (!(Test-Path $claudeDir)) {
        New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null
    }
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
    $name = $_.BaseName
    if ($useSymlink) {
        New-Item -ItemType SymbolicLink -Path $target -Target $_.FullName -Force | Out-Null
    } else {
        Copy-Item $_.FullName -Destination $target -Force
    }
    Write-Host "  커맨드: /$name"
    $cmdCount++
}

# Agents 설치
$agentDir = Join-Path $claudeDir "agents"
if (!(Test-Path $agentDir)) {
    New-Item -ItemType Directory -Path $agentDir -Force | Out-Null
}
Get-ChildItem "$scriptDir\agents\*.md" | ForEach-Object {
    $target = Join-Path $agentDir $_.Name
    if (Test-Path $target) { Remove-Item $target -Force }
    $name = $_.BaseName
    if ($useSymlink) {
        New-Item -ItemType SymbolicLink -Path $target -Target $_.FullName -Force | Out-Null
    } else {
        Copy-Item $_.FullName -Destination $target -Force
    }
    Write-Host "  에이전트: $name"
    $agentCount++
}

# 검증
$installedCmds = (Get-ChildItem "$cmdDir\*.md" -ErrorAction SilentlyContinue).Count
$installedAgents = (Get-ChildItem "$agentDir\*.md" -ErrorAction SilentlyContinue).Count

Write-Host ""
$mode = if ($useSymlink) { "심링크 방식 — 소스 수정 시 즉시 반영" } else { "복사 방식 — 소스 수정 후 install.ps1 재실행 필요" }
Write-Host "설치 완료 ($mode)"
Write-Host "  커맨드: ${cmdCount}개 설치 (${installedCmds}개 확인)"
Write-Host "  에이전트: ${agentCount}개 설치 (${installedAgents}개 확인)"
Write-Host ""
Write-Host "주요 커맨드:"
Write-Host "  /start  — 프로젝트 시작 (총괄 오케스트레이터)"
Write-Host "  /who    — 전문가 안내"
Write-Host "  /dev    — TDD 기반 개발"
Write-Host "  /qa     — 테스트 커버리지 구축"
Write-Host "  /evolve — 자가발전 모드"
Write-Host "  /tips   — Claude Code 기능 가이드"
Write-Host ""
Write-Host "제거: .\install.ps1 -Uninstall"
