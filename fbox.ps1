<#
.SYNOPSIS
ファイルの一覧をリストボックスで標示しGUIアプリへD&Dするスクリプト

.EXAMPLE
ls | fbox.ps1

.INPUTS
ファイル

.OUTPUTS
リストボックス

#>

using namespace System.Windows.Forms
using namespace System.Drawing
using namespace System.IO


param(
    [string]
    $Path,
    [switch]
    $Help
)
if ($Help) {
    Get-Help $MyInvocation.MyCommand.Path
    Exit 1
}

# アセンブリのロード
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Main
{
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline=$true,Mandatory=$true)]
        [string[]]
        $path
    )
    begin
    {
        # メインフォームの生成
        $form = [Form]::new() | % {
            $_.Name = "MAIN_FORM"
            $_.Size = "800,600"
            $_
        }

        # リストビュー
        $lv = [ListBox]::new() | % {
            $_.Name = "FILELIST"
            $_.Dock = "Fill"
            $_.Font = ",16"
            $_.Add_MouseDown(
                {
                    [string[]]$array = $lv.SelectedItem.ToString()

                    $obj = [DataObject]::new("FileDrop", $array)
                    $lv.DoDragDrop($obj, "Copy")
                })
            $_
        }

    }
    process
    {
        $path | % -process {
            $lv.Items.Add($_) | Out-Null
        }

    }
    end
    {
        # フォームにコントロールを配置
        $form.Controls.Add($lv)

        # フォームの表示
        $form.ShowDialog()
    }

        
}
$args = @($input)

if ($Help -Or ( -Not $Path -And $args.Count -eq 0))
{
    Get-Help $PSCommandPath
    Exit 1
}

if ($args.Count -gt 0)
{
    if ($args[0] -is [System.IO.FileSystemInfo])
    {
        $args | ForEach-Object { $_.FullName } | Main
    }
    else
    {
        $args | Main
    }
}
else
{
    Main -path $Path
}