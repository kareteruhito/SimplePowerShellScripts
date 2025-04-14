<#
.SYNOPSIS
画像ファイルをPngファイルへ変換

.DESCRIPTION
ps1スクリプトの練習用スクリプトです。System.Drawing.Imageを使い画像ファイルを読込⇒PNG保存を行います。

.EXAMPLE
Convert-ImageToPng.ps1 -Path Jpegファイル　-Outdir = "./"

.PARAMETER $Path
画像ファイルのパス

.PARAMETER $Outdir
出力先のディレクトリパス

.EXAMPLE
Convert-ImageToPng.ps1 -Path "F:\Pictures\00000-2181776672.jpg"

.EXAMPLE
Get-ChildItem "F:\Pictures" -Filter "*.jpg" | Convert-ImageToPng.ps1

#>
param(
    [string]
    $Path,
    [string]
    $Outdir = ".",
    [switch]
    $Help
)
if ($Help) {
    Get-Help $MyInvocation.MyCommand.Path
    Exit 1
}

Add-Type -AssemblyName System.Drawing

function Convert-ImageToPng
{
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline=$true,Mandatory=$true)]
        [string[]] $path,
        [Parameter(ValueFromPipeline=$false,Mandatory=$true)]
        [string] $odir
    )
    begin {}
    process
    {
        foreach ($p in $path)
        {
            $path = Convert-Path $path
            $odir = Convert-Path $odir

            $fileStr = Split-Path $path -Leaf
            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($fileStr)
            $outFile = (Join-Path $odir ($baseName+".png"))

            $bmp = [System.Drawing.Image]::FromFile($path)
            Write-Output $path
            $bmp.Save($outFile, [System.Drawing.Imaging.ImageFormat]::Png)
            $bmp.Dispose(); $bmp = $null
        }
    }
    end {}

        
}

# パイプライン入力から配列を生成
$args = @($input)

# ヘルプの標示
if ($Help -Or ( -Not $Path -And $args.Count -eq 0))
{
    Get-Help $PSCommandPath
    Exit 1
}

# 出力先のディレクトリ作成
$Outdir = Convert-Path $Outdir
if (-not (Test-Path $Outdir))
{
    New-Item $Outdir -ItemType Directory | Out-Null
}

# 対象ファイルが複数単数で分岐
if ($args.Count -gt 0)
{
    if ($args[0] -is [System.IO.FileSystemInfo])
    {
        # ls | ThisScript.ps1
        $args | ForEach-Object { $_.FullName } | Convert-ImageToPng -odir $Outdir
    }
    else
    {
        # "./path/file1.jpg", "./path/file1.jpg" | ThisScript.ps1
        $args | Convert-ImageToPng -odir $Outdir
    }
}
else
{
    # ThisScript.ps1 "./path/file1.jpg"
    Convert-ImageToPng -path $Path -odir $Outdir
}