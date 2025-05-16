<#
.SYNOPSIS
CSharp用のクラスファイルを生成

.DESCRIPTION
引数オブジェクトを内部メンバーに

.EXAMPLE
Genarate-CsClass.ps1 -ClassName MyClass -DIObject OtherClass

.PARAMETER $ClassName
クラス名(必須)

.PARAMETER $DIObject
依存注入用オブジェクトのクラス名

.PARAMETER $Namespace
生成するクラスのネームスペース (指定がない場合は現在のディレクトリ名)
#>
param(
    [Parameter(Mandatory=$true)]
    [string]
    $ClassName,
    [string]
    $DIObject = "",
    [string]
    $Namespace = (Split-Path (Get-Location).Path -Leaf),
    [switch]
    $Help
)
if ($Help) {
    Get-Help $MyInvocation.MyCommand.Path
    Exit 1
}
# ヘルパー関数: 文字列の最初の文字を小文字にする
function ToLowerFirstChar([string]$str)
{
    if ([string]::IsNullOrEmpty($str))
    {
        return $str
    }
    return [char]::ToLower($str[0]) + $str.Substring(1)
}


$dir = (Get-Location).Path

$header = @"
namespace ${Namespace};


"@

$body = @"
public class ${ClassName}
{

}
"@

if ($DIObject -ne "")
{
    $varName = ToLowerFirstChar $DIObject;
    
    $body = @"
public class ${ClassName}
{
    ${DIObject} _${varName}
    public ${ClassName}(${DIObject} ${varName})
    {
        _${varName} = ${varName}
    }
}
"@
}
$text = $header + $body
$text

$text | Set-Content -Path (Join-Path $dir "${ClassName}.cs") -Encoding utf8NoBOM

# ヘルパー関数: 文字列の最初の文字を小文字にする
function String.ToLowerFirstChar()
{
    if ([string]::IsNullOrEmpty($this))
    {
        return $this
    }
    return [char]::ToLower($this[0]) + $this.Substring(1)
}