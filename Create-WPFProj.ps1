<#
.SYNOPSIS
WPF用プロジェクトの作成

.DESCRIPTION
ReactivePropertyが使える状態のプロジェクトを作成
プロジェクト用ディレクトリを作成し移動した状態で実行のこと

.EXAMPLE
Create-WPFProj.ps1

.LINK
関連URL

#>

dotnet new wpf
dotnet add package Microsoft.Xaml.Behaviors.Wpf --version 1.1.135
dotnet add package ReactiveProperty.WPF --version 9.6.0

$ProjectName = Split-Path -Leaf (Get-location).Path

# ViewModel
$MainWindowViewModel = @"
using System.Diagnostics;
using System.ComponentModel;
using Reactive.Bindings;
using Reactive.Bindings.Extensions;
using System.Reactive.Disposables;

namespace $ProjectName;
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
    /**************************************************************************
    * プロパティ
    **************************************************************************/
    public ReactiveProperty<string> Title { get; private set; }
    public MainWindowViewModel()
    {
        Title = new ReactiveProperty<string>("Title").AddTo(this.Disposable);
    }
}
"@

$outFile = Join-Path (Get-location).Path "MainWindowViewModel.cs"
$writer = New-Object System.IO.StreamWriter($outFile, $false, [System.Text.Encoding]::GetEncoding("utf-8"))
$writer.WriteLine($MainWindowViewModel)
$writer.Close()

# ViewModelCleanupBehavior
$ViewModelCleanupBehavior = @"
using Microsoft.Xaml.Behaviors;
using System.Windows;

namespace $ProjectName;
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
$outFile = Join-Path (Get-location).Path "ViewModelCleanupBehavior.cs"
$writer = New-Object System.IO.StreamWriter($outFile, $false, [System.Text.Encoding]::GetEncoding("utf-8"))
$writer.WriteLine($ViewModelCleanupBehavior)
$writer.Close()

# XAML
$inFile = Join-Path (Get-location).Path "MainWindow.xaml"
$xmlDoc = [System.Xml.XmlDocument](Get-Content -Encoding UTF8 -Raw $inFile)

$ns = "http://schemas.microsoft.com/winfx/2006/xaml/presentation"
$nslocal = "clr-namespace:${ProjectName}"
$nsi = "clr-namespace:Microsoft.Xaml.Behaviors;assembly=Microsoft.Xaml.Behaviors"
$nsinteractivity = "clr-namespace:Reactive.Bindings.Interactivity;assembly=ReactiveProperty.WPF"

$attri = $xmlDoc.CreateAttribute("xmlns:i")
$attri.Value = $nsi
$xmlDoc.Window.Attributes.Append($attri) | Out-Null

$attri2 = $xmlDoc.CreateAttribute("xmlns:interactivity")
$attri2.Value = $nsinteractivity
$xmlDoc.Window.Attributes.Append($attri) | Out-Null

$xmlDoc.Window.setAttribute("Title", "{Binding Title.Value}")

$child = $xmlDoc.CreateElement("Window.DataContext", $ns)
$child2 = $xmlDoc.CreateElement("local:MainWindowViewModel", $nslocal)

$pos = $xmlDoc.getElementsByTagName("Grid")[0]
$dc = $xmlDoc.Window.insertBefore($child, $pos)
$dc.appendChild($child2) | Out-Null


$child3 = $xmlDoc.CreateElement("i:Interaction.Behaviors", $nsi)
$child4 = $xmlDoc.CreateElement("local:ViewModelCleanupBehavior", $nslocal)

$ib = $xmlDoc.Window.insertBefore($child3, $pos)
$ib.appendChild($child4) | Out-Null

$xmlDoc.Save($inFile) 

# Windowが長いので改行
$txt = Get-Content $inFile | ForEach-Object -Begin{$i=0} -Process { if($i -eq 0) { $_ -replace '" ', """`n`t" } else { $_ }; $i++ }
Set-Content -Path $inFile -Value $txt

# csproj
$inFile = Join-Path (Get-location).Path ($ProjectName + ".csproj")
$xmlDoc = [System.Xml.XmlDocument](Get-Content -Encoding UTF8 -Raw $inFile)

$child4 = $xmlDoc.CreateElement("NoWarn")
$child4.InnerText = "NU1701"
$pos = $xmlDoc.getElementsByTagName("UseWPF")[0]
$xmlDoc.Project.PropertyGroup.insertAfter($child4, $pos) | Out-Null
$xmlDoc.Save($inFile)