<#
.SYNOPSIS
WPFプロジェクトを含むソリューションを作成

.DESCRIPTION
WPFのアプリケーション、ライブラリとコンソールプロジェクトを作成します。
アプリケーションにはView

.EXAMPLE
mkdir ソリューション名
cd ソリューション名
Create-WPFSolution.ps1

#>

$ErrorActionPreference = "STOP" # エラーが発生した場合スクリプトを停止する。

$SolutionName = Split-Path (Get-Location).Path -Leaf 
$result =Read-Host "Do you want to create a ${SolutionName} solution?(Y/N)"
if ($result.ToUpper() -ne "Y") {
    Exit
}
dotnet new sln --name $SolutionName # ソリューションの作成


# クラスライブラリ作成(Domain)

New-Item -ItemType Directory -Path "${SolutionName}.Domain"
dotnet new classlib --name "${SolutionName}.Domain" --output "${SolutionName}.Domain"
Set-Location "${SolutionName}.Domain"
dotnet sln "..\${SolutionName}.sln" add "${SolutionName}.Domain.csproj"

New-Item -ItemType Directory -Path "Entities"

New-Item -ItemType Directory -Path "Exceptions"

$sourceCode = @"
using System;

namespace ${SolutionName}.Domain.Exceptions;

public abstract class ExceptionBase : Exception
{
    public ExceptionBase(ExceptionType exceptionType, string message) : base(message)
    {
        ExceptionType = exceptionType;
    }

    public ExceptionType ExceptionType { get; }
}
"@
$outFile = Join-Path (Get-location).Path "Exceptions/ExceptionBase.cs"
$writer = New-Object System.IO.StreamWriter($outFile, $false, [System.Text.Encoding]::GetEncoding("utf-8"))
$writer.WriteLine($sourceCode)
$writer.Close()

$sourceCode = @"
using System;

namespace ${SolutionName}.Domain.Exceptions;

public enum ExceptionType
{
    Information,
    Warning,
    Error,
}
"@
$outFile = Join-Path (Get-location).Path "Exceptions/ExceptionType.cs"
$writer = New-Object System.IO.StreamWriter($outFile, $false, [System.Text.Encoding]::GetEncoding("utf-8"))
$writer.WriteLine($sourceCode)
$writer.Close()

New-Item -ItemType Directory -Path "Helpers"

New-Item -ItemType Directory -Path "Repositories"

New-Item -ItemType Directory -Path "ValueObjects"

$sourceCode = @"
using System;

namespace ${SolutionName}.Domain.ValueObjects;

public abstract class ValueObject<T> where T : ValueObject<T>
{
    public override bool Equals(object? obj)
    {
        var vo = obj as T;
        if (vo == null)
        {
            return false;
        }

        return EqualsCore(vo);
    }

    public static bool operator ==(ValueObject<T>? vo1, ValueObject<T>? vo2)
    {
        return Equals(vo1, vo2);
    }

    public static bool operator !=(ValueObject<T>? vo1, ValueObject<T>? vo2)
    {
        return !Equals(vo1, vo2);
    }

    public override int GetHashCode()
    {
        return base.GetHashCode();
    }

    protected abstract bool EqualsCore(T other);
}
"@
$outFile = Join-Path (Get-location).Path "ValueObjects/ValueObject.cs"
$writer = New-Object System.IO.StreamWriter($outFile, $false, [System.Text.Encoding]::GetEncoding("utf-8"))
$writer.WriteLine($sourceCode)
$writer.Close()



Set-Location ".."

# クラスライブラリ作成(Infrastructure)

New-Item -ItemType Directory -Path "${SolutionName}.Infrastructure"
dotnet new classlib --name "${SolutionName}.Infrastructure" --output "${SolutionName}.Infrastructure"
Set-Location "${SolutionName}.Infrastructure"
dotnet add reference "..\${SolutionName}.Domain"
dotnet sln "..\${SolutionName}.sln" add "${SolutionName}.Infrastructure.csproj"

New-Item -ItemType Directory -Path "Fake"

New-Item -ItemType Directory -Path "Services"

Set-Location ".."


# WPFプロジェクトの作成
New-Item -ItemType Directory -Path "${SolutionName}.WPFApp"
dotnet new wpf --name "${SolutionName}.WPFApp" --output "${SolutionName}.WPFApp"
Set-Location "${SolutionName}.WPFApp"


# csproj
$inFile = Join-Path (Get-location).Path ("${SolutionName}.WPFApp.csproj")
$xmlDoc = [System.Xml.XmlDocument](Get-Content -Encoding UTF8 -Raw $inFile)

$child4 = $xmlDoc.CreateElement("NoWarn")
$child4.InnerText = "NU1701"
$pos = $xmlDoc.getElementsByTagName("UseWPF")[0]
$xmlDoc.Project.PropertyGroup.insertAfter($child4, $pos) | Out-Null
$xmlDoc.Save($inFile)

dotnet sln "..\${SolutionName}.sln" add "${SolutionName}.WPFApp.csproj"
dotnet add reference "..\${SolutionName}.Domain"
dotnet add reference "..\${SolutionName}.Infrastructure"
dotnet add package Microsoft.Xaml.Behaviors.WPF
dotnet add package ReactiveProperty.WPF

New-Item -ItemType Directory -Path "ViewModel"
New-Item -ItemType Directory -Path "View"
New-Item -ItemType Directory -Path "Model"
New-Item -ItemType Directory -Path "Behavior"
New-Item -ItemType Directory -Path "Converter"

# ViewModel
$MainWindowViewModel = @"
using System.Diagnostics;
using System;
using System.ComponentModel;
using Reactive.Bindings;
using Reactive.Bindings.Extensions;
using System.Reactive.Disposables;

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
    public ReactiveProperty<string> Title { get; private set; } = new("${SolutionName}");
    public MainWindowViewModel()
    {
        Title.AddTo(Disposable);
    }
}
"@

$outFile = Join-Path (Get-location).Path "ViewModel\MainWindowViewModel.cs"
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

namespace ${SolutionName}.WPFApp.Behavior;

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
$outFile = Join-Path (Get-location).Path "Behavior\ViewModelCleanupBehavior.cs"
$writer = New-Object System.IO.StreamWriter($outFile, $false, [System.Text.Encoding]::GetEncoding("utf-8"))
$writer.WriteLine($ViewModelCleanupBehavior)
$writer.Close()

# BooleanToVisibilityConverter
$BooleanToVisibilityConverter = @"
using System.Windows;
using System.Windows.Data;


namespace ${SolutionName}.WPFApp.Converter;

/// <summary>
/// boolをVisibilityへ変換するコンバータ。
/// .DESCRIPTION
/// 
/// .EXAMPLE
/// XAML
/// <TextBlock Text="aaa" Visibility="{Binding IsEditing.Value, Converter={StaticResource BooleanToVisibilityConverter}, ConverterParameter=Collapsed}">
/// </summary>
public class BooleanToVisibilityConverter : IValueConverter
{
    public object Convert(object value, System.Type targetType, object parameter, System.Globalization.CultureInfo culture)
    {
        bool visibility = (bool)value;
        string? parameterString = parameter as string;
        bool reverse = (parameterString != null && parameterString.ToLower() == "collapsed");
        return (visibility ^ reverse) ? Visibility.Visible : Visibility.Collapsed;
    }

    public object ConvertBack(object value, System.Type targetType, object parameter, System.Globalization.CultureInfo culture)
    {
        return value is Visibility.Visible;
    }
}
"@
$outFile = Join-Path (Get-location).Path "Converter\BooleanToVisibilityConverter.cs"
$writer = New-Object System.IO.StreamWriter($outFile, $false, [System.Text.Encoding]::GetEncoding("utf-8"))
$writer.WriteLine($BooleanToVisibilityConverter)
$writer.Close()




# XAML
$inFile = Join-Path (Get-location).Path "MainWindow.xaml"
$xmlDoc = [System.Xml.XmlDocument](Get-Content -Encoding UTF8 -Raw $inFile)

$ns = "http://schemas.microsoft.com/winfx/2006/xaml/presentation"
$nslocal = "clr-namespace:${SolutionName}.WPFApp"
$nsi = "clr-namespace:Microsoft.Xaml.Behaviors;assembly=Microsoft.Xaml.Behaviors"
$nsinteractivity = "clr-namespace:Reactive.Bindings.Interactivity;assembly=ReactiveProperty.WPFApp"

$attri = $xmlDoc.CreateAttribute("xmlns:i")
$attri.Value = $nsi
$xmlDoc.Window.Attributes.Append($attri) | Out-Null

$attri2 = $xmlDoc.CreateAttribute("xmlns:interactivity")
$attri2.Value = $nsinteractivity
$xmlDoc.Window.Attributes.Append($attri2) | Out-Null

$attri3 = $xmlDoc.CreateAttribute("xmlns:view")
$attri3.Value = "clr-namespace:${SolutionName}.WPFApp.View"
$xmlDoc.Window.Attributes.Append($attri3) | Out-Null

$attri4 = $xmlDoc.CreateAttribute("xmlns:viewModel")
$attri4.Value = "clr-namespace:${SolutionName}.WPFApp.ViewModel"
$xmlDoc.Window.Attributes.Append($attri4) | Out-Null

$attri5 = $xmlDoc.CreateAttribute("xmlns:behavior")
$attri5.Value = "clr-namespace:${SolutionName}.WPFApp.Behavior"
$xmlDoc.Window.Attributes.Append($attri5) | Out-Null

$attri6 = $xmlDoc.CreateAttribute("xmlns:converter")
$attri6.Value = "clr-namespace:${SolutionName}.WPFApp.Converter"
$xmlDoc.Window.Attributes.Append($attri6) | Out-Null

$xmlDoc.Window.setAttribute("Title", "{Binding Title.Value}")

$xmlDoc.Window.setAttribute("x:Class", "${SolutionName}.WPFApp.View.MainWindow")

$child = $xmlDoc.CreateElement("Window.DataContext", $ns)
$child2 = $xmlDoc.CreateElement("viewModel:MainWindowViewModel", "clr-namespace:${SolutionName}.WPFApp.ViewModel")

$pos = $xmlDoc.getElementsByTagName("Grid")[0]
$dc = $xmlDoc.Window.insertBefore($child, $pos)
$dc.appendChild($child2) | Out-Null


$child3 = $xmlDoc.CreateElement("i:Interaction.Behaviors", $nsi)
$child4 = $xmlDoc.CreateElement("behavior:ViewModelCleanupBehavior", "clr-namespace:${SolutionName}.WPFApp.Behavior")

$ib = $xmlDoc.Window.insertBefore($child3, $pos)
$ib.appendChild($child4) | Out-Null

$xmlDoc.Save($inFile) 

# Windowが長いので改行
$txt = Get-Content $inFile | ForEach-Object -Begin{$i=-1;$i++} -Process { if($i -eq 0) { $_ -replace '" ', """`n`t" } else { $_ }; $i++ }
Set-Content -Path $inFile -Value $txt

$outFile = Join-Path (Get-location).Path "View\MainWindow.xaml"
Move-Item -Path $inFile -Destination $outFile


# MainWindow.xaml.cs
$MainWindow_xaml_cs = @"
using System.Text;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Documents;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Navigation;
using System.Windows.Shapes;

namespace ${SolutionName}.WPFApp.View;

/// <summary>
/// Interaction logic for MainWindow.xaml
/// </summary>
public partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();
    }
}
"@
$outFile = Join-Path (Get-location).Path "View\MainWindow.xaml.cs"
$writer = New-Object System.IO.StreamWriter($outFile, $false, [System.Text.Encoding]::GetEncoding("utf-8"))
$writer.WriteLine($MainWindow_xaml_cs)
$writer.Close()

$inFile = Join-Path (Get-location).Path "MainWindow.xaml.cs"
Remove-Item -Path $inFile



# App.xaml

$inFile = Join-Path (Get-location).Path "App.xaml"
$xmlDoc = [System.Xml.XmlDocument](Get-Content -Encoding UTF8 -Raw $inFile)

$xmlDoc.Application.setAttribute("StartupUri", "View/MainWindow.xaml")

$xmlDoc.Save($inFile) 

# Windowが長いので改行
$txt = Get-Content $inFile | ForEach-Object -Begin{$i=-1;$i++} -Process { if($i -eq 0) { $_ -replace '" ', """`n`t" } else { $_ }; $i++ }
Set-Content -Path $inFile -Value $txt


Set-Location ".."



# コンソールアプリ 作成
New-Item -ItemType Directory -Path "${SolutionName}.ConsoleApp"
dotnet new console --name "${SolutionName}.ConsoleApp"  --output "${SolutionName}.ConsoleApp"
Set-Location "${SolutionName}.ConsoleApp"

# ConsoleプロジェクトのターゲットフレームワークをnetX.XからnetX.X-windowsへ変更
$inFile = Join-Path (Get-location).Path "${SolutionName}.ConsoleApp.csproj"
$xmlDoc = [System.Xml.XmlDocument](Get-Content -Encoding UTF8 -Raw $inFile)

$target = $xmlDoc.Project.PropertyGroup.TargetFramework

if ($target -match '^net\d.\d$') {
    $xmlDoc.Project.PropertyGroup.TargetFramework = ($target + "-windows")
}

$xmlDoc.Save($inFile) 

dotnet sln "..\${SolutionName}.sln" add "${SolutionName}.ConsoleApp.csproj"
dotnet add reference "..\${SolutionName}.Domain"
dotnet add reference "..\${SolutionName}.Infrastructure"
dotnet add package System.Console

$sourceCode = @"
namespace ${SolutionName}.ConsoleApp;

class Program
{
    static void Main()
    {
        Console.WriteLine($"Hello");
    }
}
"@
$outFile = Join-Path (Get-location).Path "Program.cs"
$writer = New-Object System.IO.StreamWriter($outFile, $false, [System.Text.Encoding]::GetEncoding("utf-8"))
$writer.WriteLine($sourceCode)
$writer.Close()



Set-Location ..


# 単体テスト(MSTest) 作成
New-Item -ItemType Directory -Path "${SolutionName}Tests"
dotnet new mstest --name "${SolutionName}Tests"  --output "${SolutionName}Tests"
Set-Location "${SolutionName}Tests"

# ConsoleプロジェクトのターゲットフレームワークをnetX.XからnetX.X-windowsへ変更
$inFile = Join-Path (Get-location).Path "${SolutionName}Tests.csproj"
$xmlDoc = [System.Xml.XmlDocument](Get-Content -Encoding UTF8 -Raw $inFile)

$target = $xmlDoc.Project.PropertyGroup.TargetFramework

if ($target -match '^net\d.\d$') {
    $xmlDoc.Project.PropertyGroup.TargetFramework = ($target + "-windows")
}
$child5 = $xmlDoc.CreateElement("NoWarn")
$child5.InnerText = "NU1701"
$pos = $xmlDoc.getElementsByTagName("Nullable")[0]
$xmlDoc.Project.PropertyGroup.insertAfter($child5, $pos) | Out-Null

$child6 = $xmlDoc.CreateElement("RuntimeHostConfigurationOption")
$child6.SetAttribute("Include", "System.Runtime.Loader.UseRidGraph")
$child6.SetAttribute("Value", "true")

$pos = $xmlDoc.getElementsByTagName("ItemGroup")[0]
$pos.appendChild($child6) | Out-Null

$xmlDoc.Save($inFile) 


dotnet sln "..\${SolutionName}.sln" add "${SolutionName}Tests.csproj"
dotnet add reference "..\${SolutionName}.Domain"
dotnet add reference "..\${SolutionName}.Infrastructure"
dotnet add reference "..\${SolutionName}.WPFApp"
dotnet add package Mock

Set-Location ..