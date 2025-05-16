<#
.SYNOPSIS
WPF用単体テスト付きプロジェクトの作成

.DESCRIPTION
ReactivePropertyが使える状態のプロジェクトを作成
プロジェクト用ディレクトリを作成し移動した状態で実行のこと

.EXAMPLE
mkdir ソリューション名
cd ソリューション名
Create-WPFTestProj.ps1

.LINK
関連URL

#>

$ErrorActionPreference = "STOP" # エラーが発生した場合スクリプトを停止する。

# 作成者
$Authoer = "MayWork.net"

# ソリューションの作成

$SolutionName = Split-Path (Get-Location).Path -Leaf 
$result =Read-Host "Do you want to create a ${SolutionName} solution?(Y/N)"
if ($result.ToUpper() -ne "Y") {
    Exit
}
Remove-Item *
dotnet new sln --name $SolutionName 

# ドメイン - クラスライブラリ作成

New-Item -ItemType Directory -Path "${SolutionName}.Domain"
dotnet new classlib --name "${SolutionName}.Domain" --output "${SolutionName}.Domain"
Set-Location "${SolutionName}.Domain"
dotnet sln "..\${SolutionName}.sln" add "${SolutionName}.Domain.csproj"

$sourceCode = @"
using System;

namespace ${SolutionName}.Domain;

public class Dummy
{
    /* ダミークラス
    ここはドメイン領域。ビジネスロジックを記述する場所
    アプリケーションロジック(WPF)やデータベースアクセス(Infrastructure)が含まれていないか確認
    */
}
"@
$outFile = Join-Path (Get-location).Path "Dummy.cs"
$writer = New-Object System.IO.StreamWriter($outFile, $false, [System.Text.Encoding]::GetEncoding("utf-8"))
$writer.WriteLine($sourceCode)
$writer.Close()

Set-Location ".."

# インフラストラクチャ - クラスライブラリ作成

New-Item -ItemType Directory -Path "${SolutionName}.Infrastructure"
dotnet new classlib --name "${SolutionName}.Infrastructure" --output "${SolutionName}.Infrastructure"
Set-Location "${SolutionName}.Infrastructure"
dotnet sln "..\${SolutionName}.sln" add "${SolutionName}.Infrastructure.csproj"
dotnet add reference "..\${SolutionName}.Domain"

$sourceCode = @"
using System;

using ${SolutionName}.Domain;

namespace ${SolutionName}.Infrastructure;

public class Dummy
{
    /* ダミークラス
    ここはインフラストラクチャ領域。主にデータベースに直接アクセスするコードを記述する場所
    ドメイン・クラスライブラリを参照
    */
}
"@
$outFile = Join-Path (Get-location).Path "Dummy.cs"
$writer = New-Object System.IO.StreamWriter($outFile, $false, [System.Text.Encoding]::GetEncoding("utf-8"))
$writer.WriteLine($sourceCode)
$writer.Close()

Set-Location ".."


# WPFプロジェクトの作成
New-Item -ItemType Directory -Path "${SolutionName}.WPFApp"
dotnet new wpf --name "${SolutionName}.WPFApp" --output "${SolutionName}.WPFApp"
Set-Location "${SolutionName}.WPFApp"


# csproj
$inFile = Join-Path (Get-location).Path ("${SolutionName}.WPFApp.csproj")
$xmlDoc = [System.Xml.XmlDocument](Get-Content -Encoding UTF8 -Raw $inFile)

$child4 = $xmlDoc.CreateElement("NoWarn")
$child4.InnerText = "NU1701" # 互換性警告無視
$pos = $xmlDoc.getElementsByTagName("UseWPF")[0]
$xmlDoc.Project.PropertyGroup.insertAfter($child4, $pos) | Out-Null
$xmlDoc.Save($inFile)

dotnet sln "..\${SolutionName}.sln" add "${SolutionName}.WPFApp.csproj"
dotnet add reference "..\${SolutionName}.Domain"
dotnet add reference "..\${SolutionName}.Infrastructure"
dotnet add package Microsoft.Xaml.Behaviors.WPF
dotnet add package ReactiveProperty.WPF

# ViewModel
$MainWindowViewModel = @"
using System.Diagnostics;
using System;
using System.ComponentModel;
using Reactive.Bindings;
using Reactive.Bindings.Extensions;
using System.Reactive.Disposables;

using ${SolutionName}.Domain;
using ${SolutionName}.Infrastructure;

namespace ${SolutionName}.WPFApp.ViewModel;

public class MainWindowViewModel : INotifyPropertyChanged, IDisposable
{
#region
    // INotifyPropertyChanged
    public event PropertyChangedEventHandler? PropertyChanged;
    protected virtual void OnPropertyChanged(string name) =>
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
    // IDisposable
    private CompositeDisposable Disposable { get; } = [];
    public void Dispose() => Disposable.Dispose();
#endregion
    public MainWindowViewModel()
    {
    }
}
"@

if (-not (Test-Path -Path "ViewModel" -PathType Container)) { New-Item -Path "ViewModel" -ItemType Directory }
$outFile = Join-Path (Get-location).Path "ViewModel/MainWindowViewModel.cs"
$writer = New-Object System.IO.StreamWriter($outFile, $false, [System.Text.Encoding]::GetEncoding("utf-8"))
$writer.WriteLine($MainWindowViewModel)
$writer.Close()

# ViewModelCleanupBehavior
$ViewModelCleanupBehavior = @"
using System.Xml;
using System.Xml.Schema;

using Microsoft.Xaml.Behaviors;
using System;
using System.Windows;
using System.ComponentModel;

namespace ${Authoer}.Behavior;

public class ViewModelCleanupBehavior : Behavior<Window>
{
    protected override void OnAttached()
    {
        base.OnAttached();
        this.AssociatedObject.Closed += this.WindowClosed;
    }

    private void WindowClosed(object? sender, EventArgs e)
    {
        (this.AssociatedObject.DataContext as IDisposable)?.Dispose();
    }

    protected override void OnDetaching()
    {
        base.OnDetaching();
        this.AssociatedObject.Closed -= this.WindowClosed;
    }
}
"@
if (-not (Test-Path -Path "Behavior" -PathType Container)) { New-Item -Path "Behavior" -ItemType Directory }
$outFile = Join-Path (Get-location).Path "Behavior/ViewModelCleanupBehavior.cs"
$writer = New-Object System.IO.StreamWriter($outFile, $false, [System.Text.Encoding]::GetEncoding("utf-8"))
$writer.WriteLine($ViewModelCleanupBehavior)
$writer.Close()

# MainWindow.xaml

if (-not (Test-Path -Path "View" -PathType Container)) { New-Item -Path "View" -ItemType Directory }

$inFile = Join-Path (Get-location).Path "MainWindow.xaml"
Move-Item $inFile ".\View"
$inFile = Join-Path (Get-location).Path "View/MainWindow.xaml"

$xmlDoc = [System.Xml.XmlDocument](Get-Content -Encoding UTF8 -Raw $inFile)

$ns = "http://schemas.microsoft.com/winfx/2006/xaml/presentation"
#$nslocal = "clr-namespace:${SolutionName}.WPFApp"
$nsviewmodel = "clr-namespace:${SolutionName}.WPFApp.ViewModel"
$nsbehavior = "clr-namespace:${Authoer}.Behavior"
$nsinteractivity = "clr-namespace:Reactive.Bindings.Interactivity;assembly=ReactiveProperty.WPFApp"

$nsi = "clr-namespace:Microsoft.Xaml.Behaviors;assembly=Microsoft.Xaml.Behaviors"
$attri = $xmlDoc.CreateAttribute("xmlns:i")
$attri.Value = $nsi
$xmlDoc.Window.Attributes.Append($attri) | Out-Null

$attri2 = $xmlDoc.CreateAttribute("xmlns:interactivity")
$attri2.Value = $nsinteractivity
$xmlDoc.Window.Attributes.Append($attri2) | Out-Null

$xmlDoc.Window.setAttribute("Title", "${SolutionName}")

$attri3 = $xmlDoc.CreateAttribute("xmlns:viewmodel")
$attri3.Value = $nsviewmodel
$xmlDoc.Window.Attributes.Append($attri3) | Out-Null

$attri4 = $xmlDoc.CreateAttribute("xmlns:behavior")
$attri4.Value = $nsbehavior
$xmlDoc.Window.Attributes.Append($attri4) | Out-Null

$child = $xmlDoc.CreateElement("Window.DataContext", $ns)
$child2 = $xmlDoc.CreateElement("viewmodel:MainWindowViewModel", $nsviewmodel)

$pos = $xmlDoc.getElementsByTagName("Grid")[0]
$dc = $xmlDoc.Window.insertBefore($child, $pos)
$dc.appendChild($child2) | Out-Null


$child3 = $xmlDoc.CreateElement("i:Interaction.Behaviors", $nsi)
$child4 = $xmlDoc.CreateElement("behavior:ViewModelCleanupBehavior", $nsbehavior)

$ib = $xmlDoc.Window.insertBefore($child3, $pos)
$ib.appendChild($child4) | Out-Null


# Window クラス名変更
$xmlDoc.Window.setAttribute("x:Class", "${SolutionName}.WPFApp.View.MainWindow")

$xmlDoc.Save($inFile) 

# Windowが長いので改行
$txt = Get-Content $inFile | ForEach-Object -Begin{$i=-1;$i++} -Process { if($i -eq 0) { $_ -replace '" ', """`n`t" } else { $_ }; $i++ }
Set-Content -Path $inFile -Value $txt

# MainWindow.xaml.cs
$inFile = Join-Path (Get-location).Path "MainWindow.xaml.cs"
Move-Item $inFile ".\View"
$inFile = Join-Path (Get-location).Path "View/MainWindow.xaml.cs"
# namespaceにViewを追加
$txt = Get-Content $inFile | ForEach-Object { if($_ -match "namespace ${SolutionName}.WPFApp;") { "namespace ${SolutionName}.WPFApp.View;" } else { $_ } }
Set-Content -Path $inFile -Value $txt

# App.xaml

$inFile = Join-Path (Get-location).Path "App.xaml"
$xmlDoc = [System.Xml.XmlDocument](Get-Content -Encoding UTF8 -Raw $inFile)
# StartupUriプロパティ変更
$xmlDoc.Application.setAttribute("StartupUri", "View/MainWindow.xaml")

$xmlDoc.Save($inFile) 

Set-Location ".."

# テストプロジェクト
New-Item -ItemType Directory -Path "${SolutionName}Test.Tests"
dotnet new mstest --name "${SolutionName}Test.Tests" --output "${SolutionName}Test.Tests"
Set-Location "${SolutionName}Test.Tests"


# テストプロジェクトのターゲットフレームワークをnetX.XからnetX.X-windowsへ変更
$inFile = Join-Path (Get-location).Path "${SolutionName}Test.Tests.csproj"
$xmlDoc = [System.Xml.XmlDocument](Get-Content -Encoding UTF8 -Raw $inFile)

$target = $xmlDoc.Project.PropertyGroup.TargetFramework

if ($target -match '^net\d.\d$') {
    $xmlDoc.Project.PropertyGroup.TargetFramework = ($target + "-windows")
}

$xmlDoc.Save($inFile) 


dotnet sln "..\${SolutionName}.sln" add "${SolutionName}Test.Tests.csproj"
dotnet add reference "..\${SolutionName}.Domain"
dotnet add reference "..\${SolutionName}.Infrastructure"
dotnet add reference "..\${SolutionName}.WPFApp"


Set-Location ..