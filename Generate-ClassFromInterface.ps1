<#
.SYNOPSIS
interface の C# ファイルから実装クラスの C# ファイルを生成します (メソッド実装、クラス名調整)。

.DESCRIPTION
指定された interface の C# ファイルを読み込み、その interface を実装する空の class ファイルを生成します。
生成される class ファイルの名前は、interface 名から先頭の 'I' を除いたものになります。
interface 内の public メソッドのシグネチャを解析し、実装クラスに空のメソッドとして追加します。
namespace は interface ファイルと同じものを想定します。

.EXAMPLE
Generate-ClassFromInterface.ps1 -InterfaceFile "IMyInterface.cs"

.PARAMETER InterfaceFile
解析する interface の C# ファイルのパス (必須)。
#>
param(
    [Parameter(Mandatory=$true)]
    [string]
    $InterfaceFile
)

# interface ファイルが存在するか確認
if (-not (Test-Path $InterfaceFile)) {
    Write-Error "指定されたファイル '$InterfaceFile' は存在しません。"
    exit 1
}

# interface ファイルの内容を読み込む
$content = Get-Content $InterfaceFile

$namespace = ""
$interfaceName = ""
$methods = @()
$inInterface = $false

# namespace、interface 名、メソッドを抽出
foreach ($line in $content) {
    $trimmedLine = $line.Trim()

    if ($trimmedLine -like "namespace *") {
        $namespace = $trimmedLine.Substring($trimmedLine.IndexOf("namespace ") + 10).Trim()
    }
    if ($trimmedLine -like "public interface I*") {
        $interfaceNameWithI = $trimmedLine.Substring($trimmedLine.IndexOf("interface ") + 10).Trim()
        # ジェネリックな型パラメータを削除
        if ($interfaceNameWithI -like "*<*") {
            $interfaceNameWithI = $interfaceNameWithI.Substring(0, $interfaceNameWithI.IndexOf("<"))
        }
        # 先頭の 'I' を削除
        $interfaceName = $interfaceNameWithI.Substring(1)
        $inInterface = $true
        continue
    } elseif ($trimmedLine -like "public interface *") {
        $interfaceNameWithoutI = $trimmedLine.Substring($trimmedLine.IndexOf("interface ") + 10).Trim()
        if ($interfaceNameWithoutI -like "*<*") {
            $interfaceNameWithoutI = $interfaceNameWithoutI.Substring(0, $interfaceNameWithoutI.IndexOf("<"))
        }
        $interfaceName = $interfaceNameWithoutI
        $inInterface = $true
        continue
    }

    if ($inInterface) {
        if ($trimmedLine -like "public * *(*);") {
            # メソッドシグネチャを抽出
            $methodSignature = $trimmedLine.TrimEnd(';')
            $methods += $methodSignature
        } elseif ($trimmedLine -like "}") {
            $inInterface = $false
        }
    }
}

# interface 名が見つからなかった場合はエラー
if ([string]::IsNullOrEmpty($interfaceName)) {
    Write-Error "指定されたファイルから public interface 名が見つかりませんでした。"
    exit 1
}

# 実装クラス名の生成 (interface 名から 'I' を削除)
$className = $interfaceName

# メソッドの実装部分を生成
$methodImplementations = ""
foreach ($method in $methods) {
    $methodImplementations += @"
    ${method}
    {
        // TODO: 実装を記述
        throw new System.NotImplementedException();
    }
}
"@
}

# class ファイルの内容を生成
$classContent = @"
namespace ${namespace};

public class ${className} : ${interfaceName}
{
    public ${className}()
    {
        // TODO: コンストラクタの実装
    }
${methodImplementations}
}
"@

# 出力ファイルパスの生成
$directory = Split-Path $InterfaceFile -Parent
$outputFile = Join-Path $directory "${className}.cs"

# class ファイルを保存
$classContent | Set-Content -Path $outputFile -Encoding utf8NoBOM
