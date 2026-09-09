[CmdletBinding(DefaultParameterSetName = "ImportParameterSet")]
param (
    [Parameter(ParameterSetName = "ImportParameterSet")]
    [ValidateNotNullOrEmpty()]
    [switch]
    $Import,

    [Parameter(ParameterSetName = "ExportParameterSet")]
    [ValidateNotNullOrEmpty()]
    [switch]
    $Export
)
$klipper_url = "klippy-test"

function Invoke-SshCommand {
    Write-Host -ForegroundColor Cyan "ssh $klipper_url $args"
    ssh $klipper_url $args
}

function Copy-FromSsh {
    param (
        [string]$source,
        [string]$destination
    )
    Write-Host -ForegroundColor Cyan "rm $destination\*.*"
    Remove-Item "$destination\*.*"

    $arguments = @(
        "${klipper_url}:$source/*.*"
        "$destination"
    )
    Write-Host -ForegroundColor Cyan "scp $($arguments -join " ")"
    $p = Start-Process -NoNewWindow -PassThru -FilePath "scp" -ArgumentList $arguments -RedirectStandardOutput "$env:temp\scp_output.txt" -RedirectStandardError "$env:temp\scp_error.txt"
    $p.WaitForExit(5000) | Out-Null
    if ($p.ExitCode -ne 0) {
        throw "Failed to copy ${klipper_url}:$source to $destination"
    }
}

function Copy-ToSsh {
    param (
        [string]$source,
        [string]$destination
    )
    Invoke-SshCommand "rm $destination/*.*"

    $arguments = @(
        "$source\*.*"
        "${klipper_url}:$destination/"
    )
    Write-Host -ForegroundColor Cyan "scp $($arguments -join " ")"
    $p = Start-Process -NoNewWindow -PassThru -FilePath "scp" -ArgumentList $arguments -RedirectStandardOutput "$env:temp\scp_output.txt" -RedirectStandardError "$env:temp\scp_error.txt"
    $p.WaitForExit(5000) | Out-Null
    if ($p.ExitCode -ne 0) {
        throw "Failed to copy $source to ${klipper_url}:$destination"
    }
}

function Convert-ToLocalPath {
    param ([Parameter(Mandatory, Position = 0)][string]$Path)
    return $(
            if ($_.StartsWith("Happy-Hare")) {
                "$PSScriptRoot\$_"
            } elseif ($_.StartsWith("printer_data/config/mmu")) {
                $_.Replace("printer_data/config/mmu", "$PSScriptRoot/printer_data")
            } else {
                throw "Unknown remote pattern: $_"
            }
        ).Replace("/", "\")
}


if (!$Import) { $Export = $true}
if ($Export) {
    Invoke-SshCommand 'pgrep -f klippy-env/bin/python && kill `pgrep -f klippy-env/bin/python`'
}

@(
    "printer_data/config/mmu"
    "printer_data/config/mmu/base"
    "printer_data/config/mmu/addons"
    "printer_data/config/mmu/optional"
    # "Happy-Hare/.github/agents"
    # "Happy-Hare/.github/prompts"
    "Happy-Hare/extras"
    "Happy-Hare/extras/mmu"
) |
    ForEach-Object {
        [pscustomobject]@{
            Remote = $_
            Local  = Convert-ToLocalPath -Path $_
        }
    } |
    ForEach-Object {
        if (!$Import -and !$Export) {
            $_ |
                ForEach-Object {
                    [PSCustomObject]@{
                        Remote        = $_.Remote
                        ExistsRemotly = $(ssh $klipper_url "ls $($_.Remote)/*.* >/dev/null 2>&1"; $LASTEXITCODE) -eq 0
                        Local         = $_.Local
                        ExistsLocaly  = Test-Path -Path $_.Local -PathType Container
                    }
                } |
                ForEach-Object {
                    $_.ExistsRemotly = $(if ($_.ExistsRemotly) { "`e[32mYes`e[0m" } else { "`e[31mNo`e[0m" })
                    $_.ExistsLocaly  = $(if ($_.ExistsLocaly)  { "`e[32mYes`e[0m" } else { "`e[31mNo`e[0m" })
                    $_
                }


        } else {
            if ($Import) {
                Copy-FromSsh -source $_.Remote -destination $_.Local
            }
            elseif ($Export) {
                Copy-ToSsh -source $_.Local -destination $_.Remote
            }
        }
    }