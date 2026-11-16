# Dyktando - czyta słówka z pliku slowka.txt po polsku (interfejs WPF)
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Xaml
Add-Type -AssemblyName System.Speech

# Rysowanie okien bez karty graficznej: na części komputerów (np. AMD Radeon 780M, sterownik 11.2024)
# okno WPF zostaje białe przy rysowaniu sprzętowym. Programowe działa wszędzie, a przy tym oknie różnicy nie widać.
[System.Windows.Media.RenderOptions]::ProcessRenderMode = [System.Windows.Interop.RenderMode]::SoftwareOnly

$scriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$plikSlowek = Join-Path $scriptDir 'slowka.txt'
$plikStanu  = Join-Path $scriptDir 'slowka_stan.txt'

# --- Synteza mowy (głos polski) ---
$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
$glosPL = $synth.GetInstalledVoices() | Where-Object { $_.Enabled -and $_.VoiceInfo.Culture.Name -eq 'pl-PL' } | Select-Object -First 1
if ($glosPL) { $synth.SelectVoice($glosPL.VoiceInfo.Name) }
else {
    # Bez polskiego głosu słówka byłyby czytane głosem domyślnym (np. z angielską wymową), więc uprzedzamy
    [void][System.Windows.MessageBox]::Show(
        "Nie znalazłem polskiego głosu do czytania (np. Microsoft Paulina).`n`nSłówka będą czytane głosem domyślnym systemu i mogą brzmieć nie po polsku.`nInstrukcja dodania głosu jest w pliku README.md.",
        'Dyktando: brak polskiego głosu', 'OK', 'Warning')
}
$synth.SetOutputToDefaultAudioDevice()

# =====================================================================
#  Dane: słówka i ich stan
# =====================================================================
function Wczytaj-Slowka {
    if (-not (Test-Path $plikSlowek)) { return @() }
    return @(Get-Content -Path $plikSlowek -Encoding UTF8 |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -ne '' } |
        Select-Object -Unique)
}

# Format linii: OZNACZENIE|ILE_RAZY|słówko   (oznaczenie: U, P lub -)
# Obsługiwany też stary format: OZNACZENIE|słówko
$script:oznaczenia = @{}   # słówko -> 'U' (umiem, pomijane) / 'P' (powtórka, zawsze w teście)
$script:licznik = @{}      # słówko -> ile razy było w dyktandzie

function Wczytaj-Stan {
    $script:oznaczenia = @{}
    $script:licznik = @{}
    if (-not (Test-Path $plikStanu)) { return }
    foreach ($linia in (Get-Content -Path $plikStanu -Encoding UTF8)) {
        $cz = $linia.Split('|')
        $n = 0
        if ($cz.Count -ge 3 -and [int]::TryParse($cz[1], [ref]$n)) {
            $st = $cz[0]; $w = ($cz[2..($cz.Count - 1)] -join '|').Trim()
        } elseif ($cz.Count -ge 2) {
            $st = $cz[0]; $w = ($cz[1..($cz.Count - 1)] -join '|').Trim()
        } else { continue }
        if ($w -eq '') { continue }
        if ($st -eq 'U' -or $st -eq 'P') { $script:oznaczenia[$w] = $st }
        if ($n -gt 0) { $script:licznik[$w] = $n }
    }
}

function Zapisz-Stan {
    $klucze = @(@($script:oznaczenia.Keys) + @($script:licznik.Keys) | Sort-Object -Unique)
    $linie = foreach ($w in $klucze) {
        $st = $script:oznaczenia[$w]; if (-not $st) { $st = '-' }
        $n = [int]$script:licznik[$w]
        if ($st -ne '-' -or $n -gt 0) { "$st|$n|$w" }
    }
    [IO.File]::WriteAllLines($plikStanu, [string[]]@($linie), (New-Object Text.UTF8Encoding($false)))
}

function Ile-Razy($w) { return [int]$script:licznik[$w] }

Wczytaj-Stan

# =====================================================================
#  Wygląd: wspólne kolory i style (wstawiane do każdego okna)
# =====================================================================
$script:zasoby = @'
<SolidColorBrush x:Key="Tlo" Color="#F4F2EE"/>
<SolidColorBrush x:Key="TloKarty" Color="#FFFFFF"/>
<SolidColorBrush x:Key="TloPola" Color="#F1EEE8"/>
<SolidColorBrush x:Key="Tekst" Color="#1E2230"/>
<SolidColorBrush x:Key="TekstSlaby" Color="#6B7080"/>
<SolidColorBrush x:Key="Linia" Color="#E4E0D7"/>
<SolidColorBrush x:Key="Akcent" Color="#4A5BD4"/>
<SolidColorBrush x:Key="AkcentJasny" Color="#E8EBFB"/>
<SolidColorBrush x:Key="Zielony" Color="#23925E"/>
<SolidColorBrush x:Key="ZielonyJasny" Color="#E1F3E8"/>
<SolidColorBrush x:Key="Czerwony" Color="#CF4444"/>
<SolidColorBrush x:Key="CzerwonyJasny" Color="#FBE4E4"/>
<SolidColorBrush x:Key="Pomaranczowy" Color="#D27A12"/>
<SolidColorBrush x:Key="PomaranczowyJasny" Color="#FCEDD8"/>
<SolidColorBrush x:Key="Przezroczysty" Color="Transparent"/>

<Style x:Key="Karta" TargetType="Border">
  <Setter Property="Background" Value="{StaticResource TloKarty}"/>
  <Setter Property="BorderBrush" Value="{StaticResource Linia}"/>
  <Setter Property="BorderThickness" Value="1"/>
  <Setter Property="CornerRadius" Value="16"/>
  <Setter Property="Padding" Value="22"/>
</Style>

<Style x:Key="Ikona" TargetType="TextBlock">
  <Setter Property="FontFamily" Value="Segoe MDL2 Assets"/>
  <Setter Property="FontSize" Value="15"/>
  <Setter Property="VerticalAlignment" Value="Center"/>
</Style>

<Style x:Key="Przycisk" TargetType="Button">
  <Setter Property="Background" Value="{StaticResource TloKarty}"/>
  <Setter Property="Foreground" Value="{StaticResource Tekst}"/>
  <Setter Property="BorderBrush" Value="{StaticResource Linia}"/>
  <Setter Property="BorderThickness" Value="1"/>
  <Setter Property="Padding" Value="16,9"/>
  <Setter Property="FontSize" Value="14"/>
  <Setter Property="FontWeight" Value="SemiBold"/>
  <Setter Property="Cursor" Value="Hand"/>
  <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
  <Setter Property="Template">
    <Setter.Value>
      <ControlTemplate TargetType="Button">
        <Grid>
          <Border x:Name="tlo" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                  BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="10"/>
          <Border x:Name="nakladka" Background="#000000" Opacity="0" CornerRadius="10"/>
          <ContentPresenter Margin="{TemplateBinding Padding}" HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}"
                            VerticalAlignment="Center"/>
        </Grid>
        <ControlTemplate.Triggers>
          <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="nakladka" Property="Opacity" Value="0.05"/></Trigger>
          <Trigger Property="IsPressed" Value="True"><Setter TargetName="nakladka" Property="Opacity" Value="0.12"/></Trigger>
          <Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="tlo" Property="BorderBrush" Value="{StaticResource Akcent}"/></Trigger>
          <Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.4"/></Trigger>
        </ControlTemplate.Triggers>
      </ControlTemplate>
    </Setter.Value>
  </Setter>
</Style>

<Style x:Key="PrzyciskGlowny" TargetType="Button" BasedOn="{StaticResource Przycisk}">
  <Setter Property="Background" Value="{StaticResource Akcent}"/>
  <Setter Property="BorderBrush" Value="{StaticResource Akcent}"/>
  <Setter Property="Foreground" Value="White"/>
</Style>

<Style x:Key="PrzyciskZielony" TargetType="Button" BasedOn="{StaticResource Przycisk}">
  <Setter Property="Background" Value="{StaticResource Zielony}"/>
  <Setter Property="BorderBrush" Value="{StaticResource Zielony}"/>
  <Setter Property="Foreground" Value="White"/>
</Style>

<Style x:Key="Segment" TargetType="Button" BasedOn="{StaticResource Przycisk}">
  <Setter Property="Background" Value="Transparent"/>
  <Setter Property="BorderThickness" Value="0"/>
  <Setter Property="Foreground" Value="{StaticResource TekstSlaby}"/>
  <Setter Property="Padding" Value="11,5"/>
  <Setter Property="FontSize" Value="13"/>
</Style>

<Style x:Key="Segmenty" TargetType="Border">
  <Setter Property="Background" Value="{StaticResource TloPola}"/>
  <Setter Property="CornerRadius" Value="12"/>
  <Setter Property="Padding" Value="3"/>
</Style>

<Style x:Key="Krok" TargetType="RepeatButton">
  <Setter Property="Foreground" Value="{StaticResource Tekst}"/>
  <Setter Property="FontFamily" Value="Segoe MDL2 Assets"/>
  <Setter Property="FontSize" Value="11"/>
  <Setter Property="Cursor" Value="Hand"/>
  <Setter Property="Focusable" Value="False"/>
  <Setter Property="Delay" Value="400"/>
  <Setter Property="Interval" Value="60"/>
  <Setter Property="Template">
    <Setter.Value>
      <ControlTemplate TargetType="RepeatButton">
        <Border x:Name="tlo" Background="Transparent" CornerRadius="8" Margin="2">
          <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
        </Border>
        <ControlTemplate.Triggers>
          <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="tlo" Property="Background" Value="#FFFFFF"/></Trigger>
          <Trigger Property="IsPressed" Value="True"><Setter TargetName="tlo" Property="Background" Value="{StaticResource Linia}"/></Trigger>
        </ControlTemplate.Triggers>
      </ControlTemplate>
    </Setter.Value>
  </Setter>
</Style>

<Style x:Key="Licznik" TargetType="Border">
  <Setter Property="Background" Value="{StaticResource TloPola}"/>
  <Setter Property="CornerRadius" Value="10"/>
  <Setter Property="Height" Value="38"/>
</Style>

<Style x:Key="PoleLiczby" TargetType="TextBox">
  <Setter Property="Background" Value="Transparent"/>
  <Setter Property="BorderThickness" Value="0"/>
  <Setter Property="FontSize" Value="15"/>
  <Setter Property="FontWeight" Value="SemiBold"/>
  <Setter Property="Foreground" Value="{StaticResource Tekst}"/>
  <Setter Property="HorizontalContentAlignment" Value="Center"/>
  <Setter Property="VerticalContentAlignment" Value="Center"/>
  <Setter Property="MaxLength" Value="4"/>
</Style>

<Style x:Key="PoleTekstu" TargetType="TextBox">
  <Setter Property="FontSize" Value="14"/>
  <Setter Property="Foreground" Value="{StaticResource Tekst}"/>
  <Setter Property="Template">
    <Setter.Value>
      <ControlTemplate TargetType="TextBox">
        <Border x:Name="ramka" Background="{StaticResource TloKarty}" BorderBrush="{StaticResource Linia}"
                BorderThickness="1" CornerRadius="10" Padding="10,8">
          <Grid>
            <StackPanel Orientation="Horizontal" IsHitTestVisible="False">
              <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE721;" FontSize="13" Foreground="{StaticResource TekstSlaby}"
                         VerticalAlignment="Center" Margin="2,0,8,0"/>
              <TextBlock x:Name="podpowiedz" Text="{Binding Tag, RelativeSource={RelativeSource TemplatedParent}}"
                         Foreground="{StaticResource TekstSlaby}" Visibility="Hidden" VerticalAlignment="Center"/>
            </StackPanel>
            <ScrollViewer x:Name="PART_ContentHost" Margin="24,0,0,0" VerticalAlignment="Center"/>
          </Grid>
        </Border>
        <ControlTemplate.Triggers>
          <Trigger Property="Text" Value=""><Setter TargetName="podpowiedz" Property="Visibility" Value="Visible"/></Trigger>
          <Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="ramka" Property="BorderBrush" Value="{StaticResource Akcent}"/></Trigger>
        </ControlTemplate.Triggers>
      </ControlTemplate>
    </Setter.Value>
  </Setter>
</Style>

<Style x:Key="Przelacznik" TargetType="CheckBox">
  <Setter Property="Cursor" Value="Hand"/>
  <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
  <Setter Property="Foreground" Value="{StaticResource Tekst}"/>
  <Setter Property="Template">
    <Setter.Value>
      <ControlTemplate TargetType="CheckBox">
        <Grid Background="Transparent">
          <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
          <ContentPresenter VerticalAlignment="Center" Margin="0,0,14,0"/>
          <Border x:Name="tor" Grid.Column="1" Width="44" Height="24" CornerRadius="12" Background="#D3CFC6" VerticalAlignment="Center">
            <Ellipse x:Name="galka" Width="18" Height="18" Fill="White" HorizontalAlignment="Left" Margin="3,0"/>
          </Border>
        </Grid>
        <ControlTemplate.Triggers>
          <Trigger Property="IsChecked" Value="True">
            <Setter TargetName="tor" Property="Background" Value="{StaticResource Akcent}"/>
            <Setter TargetName="galka" Property="HorizontalAlignment" Value="Right"/>
          </Trigger>
          <Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.5"/></Trigger>
        </ControlTemplate.Triggers>
      </ControlTemplate>
    </Setter.Value>
  </Setter>
</Style>

<Style x:Key="SuwakPasek" TargetType="RepeatButton">
  <Setter Property="OverridesDefaultStyle" Value="True"/>
  <Setter Property="Focusable" Value="False"/>
  <Setter Property="IsTabStop" Value="False"/>
  <Setter Property="Template">
    <Setter.Value>
      <ControlTemplate TargetType="RepeatButton">
        <Grid Background="Transparent">
          <Border Height="6" CornerRadius="3" Background="{TemplateBinding Background}" VerticalAlignment="Center"/>
        </Grid>
      </ControlTemplate>
    </Setter.Value>
  </Setter>
</Style>

<Style x:Key="Suwak" TargetType="Slider">
  <Setter Property="Cursor" Value="Hand"/>
  <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
  <Setter Property="IsSnapToTickEnabled" Value="True"/>
  <Setter Property="TickFrequency" Value="1"/>
  <Setter Property="IsMoveToPointEnabled" Value="True"/>
  <Setter Property="Template">
    <Setter.Value>
      <ControlTemplate TargetType="Slider">
        <Grid Height="26">
          <Border Height="6" CornerRadius="3" Background="{StaticResource Linia}" VerticalAlignment="Center"/>
          <Track x:Name="PART_Track">
            <Track.DecreaseRepeatButton>
              <RepeatButton Command="Slider.DecreaseLarge" Style="{StaticResource SuwakPasek}" Background="{StaticResource Akcent}"/>
            </Track.DecreaseRepeatButton>
            <Track.IncreaseRepeatButton>
              <RepeatButton Command="Slider.IncreaseLarge" Style="{StaticResource SuwakPasek}" Background="Transparent"/>
            </Track.IncreaseRepeatButton>
            <Track.Thumb>
              <Thumb Width="22" Height="22">
                <Thumb.Template>
                  <ControlTemplate TargetType="Thumb">
                    <Ellipse Fill="White" Stroke="{StaticResource Akcent}" StrokeThickness="4"/>
                  </ControlTemplate>
                </Thumb.Template>
              </Thumb>
            </Track.Thumb>
          </Track>
        </Grid>
      </ControlTemplate>
    </Setter.Value>
  </Setter>
</Style>

<Style x:Key="Postep" TargetType="ProgressBar">
  <Setter Property="Height" Value="10"/>
  <Setter Property="Template">
    <Setter.Value>
      <ControlTemplate TargetType="ProgressBar">
        <Grid>
          <Border x:Name="PART_Track" CornerRadius="5" Background="{StaticResource TloPola}"/>
          <Border x:Name="PART_Indicator" CornerRadius="5" Background="{StaticResource Akcent}" HorizontalAlignment="Left"/>
        </Grid>
      </ControlTemplate>
    </Setter.Value>
  </Setter>
</Style>

<Style TargetType="ScrollBar">
  <Setter Property="Width" Value="8"/>
  <Setter Property="MinWidth" Value="8"/>
  <Setter Property="Margin" Value="4,0,0,0"/>
  <Setter Property="Template">
    <Setter.Value>
      <ControlTemplate TargetType="ScrollBar">
        <Track x:Name="PART_Track" IsDirectionReversed="True">
          <Track.Thumb>
            <Thumb>
              <Thumb.Template>
                <ControlTemplate TargetType="Thumb"><Border CornerRadius="4" Background="#CCC7BC"/></ControlTemplate>
              </Thumb.Template>
            </Thumb>
          </Track.Thumb>
        </Track>
      </ControlTemplate>
    </Setter.Value>
  </Setter>
</Style>

<Style TargetType="ToolTip">
  <Setter Property="Background" Value="#1E2230"/>
  <Setter Property="Foreground" Value="White"/>
  <Setter Property="BorderThickness" Value="0"/>
  <Setter Property="Padding" Value="10,6"/>
</Style>
'@

$script:naglowekOkna = 'xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" ' +
    'Background="#F4F2EE" FontFamily="Segoe UI" FontSize="14" Foreground="#1E2230" UseLayoutRounding="True" ' +
    'TextOptions.TextFormattingMode="Display"'

function Nowe-Okno([string]$xaml) {
    $xaml = $xaml.Replace('__NAGLOWEK__', $script:naglowekOkna).Replace('__ZASOBY__', $script:zasoby)
    $w = [Windows.Markup.XamlReader]::Parse($xaml)
    # dopasuj do mniejszych ekranów
    $ekran = [System.Windows.SystemParameters]::WorkArea
    if ($w.Height -gt $ekran.Height - 10) { $w.Height = $ekran.Height - 10 }
    if ($w.MinHeight -gt $w.Height) { $w.MinHeight = $w.Height }
    if ($w.Width -gt $ekran.Width - 10) { $w.Width = $ekran.Width - 10 }
    if ($w.MinWidth -gt $w.Width) { $w.MinWidth = $w.Width }
    return $w
}

# Tworzy zmienne o nazwach z x:Name (w zakresie wywołującego)
function Nazwane($okno, [string]$xaml) {
    foreach ($m in [regex]::Matches($xaml, 'x:Name="(\w+)"')) {
        $n = $m.Groups[1].Value
        Set-Variable -Name $n -Value $okno.FindName($n) -Scope 1
    }
}

# --- Pomocnicze funkcje do budowania elementów w kodzie ---
function Zasob($klucz) { return $script:okno.FindResource($klucz) }
function Margines($l, $t, $r, $b) { return New-Object Windows.Thickness($l, $t, $r, $b) }

function Nowy-Tekst($tekst, $rozmiar = 14, $kolor = 'Tekst', [switch]$Gruby) {
    $t = New-Object Windows.Controls.TextBlock
    $t.Text = $tekst
    $t.FontSize = $rozmiar
    $t.Foreground = Zasob $kolor
    $t.VerticalAlignment = 'Center'
    if ($Gruby) { $t.FontWeight = [Windows.FontWeights]::SemiBold }
    return $t
}

function Ikona-Z-Tekstem([int]$kod, $tekst) {
    $sp = New-Object Windows.Controls.StackPanel
    $sp.Orientation = 'Horizontal'
    $ik = New-Object Windows.Controls.TextBlock
    $ik.Style = Zasob 'Ikona'
    $ik.FontSize = 12
    $ik.Text = [string][char]$kod
    $ik.Margin = Margines 0 0 7 0
    $tx = New-Object Windows.Controls.TextBlock
    $tx.Text = $tekst
    [void]$sp.Children.Add($ik)
    [void]$sp.Children.Add($tx)
    return $sp
}

function Nowa-Kolumna($szer) {
    $c = New-Object Windows.Controls.ColumnDefinition
    if ($szer -eq '*') { $c.Width = New-Object Windows.GridLength(1, 'Star') }
    elseif ($szer -eq 'Auto') { $c.Width = [Windows.GridLength]::Auto }
    else { $c.Width = New-Object Windows.GridLength([double]$szer) }
    return $c
}

function Komunikat($tekst) {
    [void][System.Windows.MessageBox]::Show($script:okno, $tekst, 'Dyktando', 'OK', 'Information')
}

# =====================================================================
#  Okno sprawdzania testu: dobrze / źle
# =====================================================================
function Sprawdz-Test {
    $lista = @($script:stan.Lista)
    if ($lista.Count -eq 0) { return }
    $nazwyStanu = @{ 'U' = 'Umiem'; 'P' = 'Powtórka' }

    $xaml = @'
<Window __NAGLOWEK__ Title="Sprawdzenie dyktanda" Width="620" Height="740" MinWidth="540" MinHeight="520"
        WindowStartupLocation="CenterOwner" ShowInTaskbar="False">
  <Window.Resources>__ZASOBY__</Window.Resources>
  <Grid Margin="26,22,26,22">
    <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
    <StackPanel Margin="0,0,0,16">
      <TextBlock Text="Sprawdzenie dyktanda" FontSize="24" FontWeight="Bold"/>
      <TextBlock Text="Porównaj z zeszytem i zaznacz przy każdym słówku, czy zostało napisane dobrze, czy źle."
                 TextWrapping="Wrap" Foreground="{StaticResource TekstSlaby}" Margin="0,4,0,0"/>
    </StackPanel>
    <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
      <StackPanel x:Name="panelWierszy"/>
    </ScrollViewer>
    <Border Grid.Row="2" Style="{StaticResource Karta}" Padding="18,16" Margin="0,14,0,0">
      <StackPanel>
        <StackPanel Orientation="Horizontal">
          <Border Background="{StaticResource ZielonyJasny}" CornerRadius="12" Padding="12,5" Margin="0,0,8,0">
            <TextBlock x:Name="lblOk" Foreground="{StaticResource Zielony}" FontWeight="SemiBold"/>
          </Border>
          <Border Background="{StaticResource CzerwonyJasny}" CornerRadius="12" Padding="12,5" Margin="0,0,8,0">
            <TextBlock x:Name="lblZle" Foreground="{StaticResource Czerwony}" FontWeight="SemiBold"/>
          </Border>
          <Border Background="{StaticResource TloPola}" CornerRadius="12" Padding="12,5">
            <TextBlock x:Name="lblBez" Foreground="{StaticResource TekstSlaby}" FontWeight="SemiBold"/>
          </Border>
        </StackPanel>
        <CheckBox x:Name="chkZapisz" Style="{StaticResource Przelacznik}" IsChecked="True" Margin="0,16,0,0">
          <TextBlock TextWrapping="Wrap">Zapisz na liście słówek: dobrze → <Run Foreground="#23925E" FontWeight="SemiBold">Umiem</Run>, źle → <Run Foreground="#D27A12" FontWeight="SemiBold">Powtórka</Run></TextBlock>
        </CheckBox>
        <DockPanel Margin="0,16,0,0">
          <Button x:Name="btnWszystkieOK" Style="{StaticResource Przycisk}">
            <StackPanel Orientation="Horizontal">
              <TextBlock Style="{StaticResource Ikona}" FontSize="12" Text="&#xE8FB;" Margin="0,0,8,0"/>
              <TextBlock Text="Wszystkie dobrze"/>
            </StackPanel>
          </Button>
          <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
            <Button x:Name="btnZamknij" Style="{StaticResource Przycisk}" IsCancel="True" Content="Zamknij" Margin="0,0,8,0"/>
            <Button x:Name="btnZatwierdz" Style="{StaticResource PrzyciskGlowny}" Content="Zatwierdź"/>
          </StackPanel>
        </DockPanel>
      </StackPanel>
    </Border>
  </Grid>
</Window>
'@
    $dlg = Nowe-Okno $xaml
    Nazwane $dlg $xaml
    $dlg.Owner = $script:okno

    $stany = @{}       # numer wiersza -> 'ok' / 'zle'
    $wiersze = @()

    $odswiezWiersz = {
        param($i)
        $r = $wiersze[$i]; $st = $stany[$i]
        $r.Ramka.Background  = Zasob $(if ($st -eq 'ok') { 'ZielonyJasny' } elseif ($st -eq 'zle') { 'CzerwonyJasny' } else { 'TloKarty' })
        $r.Ramka.BorderBrush = Zasob $(if ($st -eq 'ok') { 'Zielony' } elseif ($st -eq 'zle') { 'Czerwony' } else { 'Linia' })
        if ($st -eq 'ok') { $r.Ok.Background = Zasob 'Zielony'; $r.Ok.BorderBrush = Zasob 'Zielony'; $r.Ok.Foreground = [Windows.Media.Brushes]::White }
        else { $r.Ok.Background = Zasob 'TloKarty'; $r.Ok.BorderBrush = Zasob 'Linia'; $r.Ok.Foreground = Zasob 'Zielony' }
        if ($st -eq 'zle') { $r.Zle.Background = Zasob 'Czerwony'; $r.Zle.BorderBrush = Zasob 'Czerwony'; $r.Zle.Foreground = [Windows.Media.Brushes]::White }
        else { $r.Zle.Background = Zasob 'TloKarty'; $r.Zle.BorderBrush = Zasob 'Linia'; $r.Zle.Foreground = Zasob 'Czerwony' }
    }

    $podsumuj = {
        $ok = @($stany.Values | Where-Object { $_ -eq 'ok' }).Count
        $zle = @($stany.Values | Where-Object { $_ -eq 'zle' }).Count
        $lblOk.Text = "Dobrze: $ok"
        $lblZle.Text = "Źle: $zle"
        $lblBez.Text = "Nie sprawdzone: $($lista.Count - $ok - $zle)"
    }

    for ($i = 0; $i -lt $lista.Count; $i++) {
        $w = $lista[$i]
        $ramka = New-Object Windows.Controls.Border
        $ramka.CornerRadius = 12
        $ramka.BorderThickness = 1
        $ramka.Padding = Margines 16 10 12 10
        $ramka.Margin = Margines 0 0 4 8

        $g = New-Object Windows.Controls.Grid
        foreach ($s in '40', '*', 'Auto', 'Auto') { [void]$g.ColumnDefinitions.Add((Nowa-Kolumna $s)) }

        $nr = Nowy-Tekst "$($i + 1)." 15 'TekstSlaby'
        [void]$g.Children.Add($nr)

        $sp = New-Object Windows.Controls.StackPanel
        $sp.VerticalAlignment = 'Center'
        [void]$sp.Children.Add((Nowy-Tekst $w 20 'Tekst' -Gruby))
        $st = $script:oznaczenia[$w]
        if ($st) {
            $kol = if ($st -eq 'U') { 'Zielony' } else { 'Pomaranczowy' }
            [void]$sp.Children.Add((Nowy-Tekst "na liście: $($nazwyStanu[$st])" 12 $kol))
        }
        [Windows.Controls.Grid]::SetColumn($sp, 1)
        [void]$g.Children.Add($sp)

        $bOk = New-Object Windows.Controls.Button
        $bOk.Style = Zasob 'Przycisk'
        $bOk.Content = Ikona-Z-Tekstem 0xE73E 'Dobrze'
        $bOk.Padding = Margines 14 8 14 8
        $bOk.Margin = Margines 8 0 0 0
        $bOk.Tag = $i
        $bOk.Add_Click({
            param($s, $e)
            $i = [int]$s.Tag
            if ($stany[$i] -eq 'ok') { $stany.Remove($i) } else { $stany[$i] = 'ok' }
            & $odswiezWiersz $i; & $podsumuj
        })
        [Windows.Controls.Grid]::SetColumn($bOk, 2)
        [void]$g.Children.Add($bOk)

        $bZle = New-Object Windows.Controls.Button
        $bZle.Style = Zasob 'Przycisk'
        $bZle.Content = Ikona-Z-Tekstem 0xE711 'Źle'
        $bZle.Padding = Margines 14 8 14 8
        $bZle.Margin = Margines 8 0 0 0
        $bZle.Tag = $i
        $bZle.Add_Click({
            param($s, $e)
            $i = [int]$s.Tag
            if ($stany[$i] -eq 'zle') { $stany.Remove($i) } else { $stany[$i] = 'zle' }
            & $odswiezWiersz $i; & $podsumuj
        })
        [Windows.Controls.Grid]::SetColumn($bZle, 3)
        [void]$g.Children.Add($bZle)

        $ramka.Child = $g
        [void]$panelWierszy.Children.Add($ramka)
        $wiersze += @{ Ramka = $ramka; Ok = $bOk; Zle = $bZle }
        & $odswiezWiersz $i
    }
    & $podsumuj

    $btnWszystkieOK.Add_Click({
        for ($i = 0; $i -lt $lista.Count; $i++) {
            if ($stany[$i] -ne 'zle') { $stany[$i] = 'ok'; & $odswiezWiersz $i }
        }
        & $podsumuj
    })
    $btnZatwierdz.Add_Click({ $dlg.DialogResult = $true })

    if ($dlg.ShowDialog() -eq $true) {
        $ok = @(); $zle = @(); $bez = @(); $wyniki = @{}
        for ($i = 0; $i -lt $lista.Count; $i++) {
            $w = $lista[$i]
            if ($stany[$i] -eq 'ok') { $ok += $w; $wyniki[$i] = 'ok' }
            elseif ($stany[$i] -eq 'zle') { $zle += $w; $wyniki[$i] = 'zle' }
            else { $bez += $w }
        }
        if ($chkZapisz.IsChecked -and ($ok.Count + $zle.Count) -gt 0) {
            foreach ($w in $ok)  { $script:oznaczenia[$w] = 'U' }
            foreach ($w in $zle) { $script:oznaczenia[$w] = 'P' }
            Zapisz-Stan
            Odswiez-Dostepne
        }
        Pokaz-Chipy $lista $wyniki
        $lblStatus.Text = "Wynik: $($ok.Count) / $($lista.Count)"
        $lblPodstatus.Text = if ($zle.Count -eq 0 -and $bez.Count -eq 0) { 'Brawo! Wszystko dobrze!' }
                             elseif ($zle.Count -gt 0) { "Do poprawy: " + ($zle -join ', ') }
                             else { "Nie sprawdzone: $($bez.Count)" }
        $lblWynikTytul.Text = "Wynik: $($ok.Count) / $($lista.Count) dobrze"
        $lblWynikOpis.Text = 'Zielone – dobrze, czerwone – źle, białe – nie sprawdzone'
    }
}

# =====================================================================
#  Okno z listą wszystkich słówek (Umiem / Powtórka, liczniki)
# =====================================================================
function Pokaz-Liste-Slowek {
    $slowka = Wczytaj-Slowka

    $xaml = @'
<Window __NAGLOWEK__ Title="Lista słówek" Width="700" Height="780" MinWidth="640" MinHeight="520"
        WindowStartupLocation="CenterOwner" ShowInTaskbar="False">
  <Window.Resources>__ZASOBY__</Window.Resources>
  <Grid Margin="26,22,26,22">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/><RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>
    <StackPanel Margin="0,0,0,16">
      <TextBlock Text="Lista słówek" FontSize="24" FontWeight="Bold"/>
      <TextBlock TextWrapping="Wrap" Foreground="{StaticResource TekstSlaby}" Margin="0,4,0,0">
        <Run Foreground="#23925E" FontWeight="SemiBold">Umiem</Run> – słówko jest pomijane w teście.
        <Run Foreground="#D27A12" FontWeight="SemiBold">Powtórka</Run> – słówko jest w każdym teście.
      </TextBlock>
    </StackPanel>
    <Grid Grid.Row="1" Margin="0,0,0,10">
      <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
      <TextBox x:Name="txtSzukaj" Style="{StaticResource PoleTekstu}" Tag="Szukaj słówka..."/>
      <Border Grid.Column="1" Style="{StaticResource Segmenty}" Margin="10,0,0,0" VerticalAlignment="Center">
        <StackPanel Orientation="Horizontal">
          <TextBlock Text="Sortuj:" FontSize="13" Foreground="{StaticResource TekstSlaby}" VerticalAlignment="Center" Margin="9,0,4,0"/>
          <Button x:Name="sortPlik" Style="{StaticResource Segment}" Content="Jak w pliku" Tag="plik"/>
          <Button x:Name="sortAZ" Style="{StaticResource Segment}" Content="A–Z" Tag="az"/>
          <Button x:Name="sortIle" Style="{StaticResource Segment}" Content="Ile razy" Tag="ile"/>
        </StackPanel>
      </Border>
    </Grid>
    <Border Grid.Row="2" Style="{StaticResource Segmenty}" HorizontalAlignment="Left" Margin="0,0,0,14">
      <StackPanel Orientation="Horizontal">
        <TextBlock Text="Pokaż:" FontSize="13" Foreground="{StaticResource TekstSlaby}" VerticalAlignment="Center" Margin="9,0,4,0"/>
        <Button x:Name="filtrWszystkie" Style="{StaticResource Segment}" Content="Wszystkie" Tag="*"/>
        <Button x:Name="filtrNauka" Style="{StaticResource Segment}" Content="Uczę się" Tag=""/>
        <Button x:Name="filtrUmiem" Style="{StaticResource Segment}" Content="Umiem" Tag="U"/>
        <Button x:Name="filtrPowtorka" Style="{StaticResource Segment}" Content="Powtórka" Tag="P"/>
      </StackPanel>
    </Border>
    <ScrollViewer Grid.Row="3" VerticalScrollBarVisibility="Auto">
      <StackPanel x:Name="panelWierszy"/>
    </ScrollViewer>
    <TextBlock x:Name="lblPusto" Grid.Row="3" Text="Brak słówek do pokazania" Foreground="{StaticResource TekstSlaby}"
               HorizontalAlignment="Center" VerticalAlignment="Top" Margin="0,30,0,0" Visibility="Collapsed"/>
    <Border Grid.Row="4" Style="{StaticResource Karta}" Padding="18,16" Margin="0,14,0,0">
      <StackPanel>
        <TextBlock x:Name="lblSuma" TextWrapping="Wrap" Foreground="{StaticResource TekstSlaby}"/>
        <DockPanel Margin="0,14,0,0">
          <StackPanel Orientation="Horizontal">
            <Button x:Name="btnWyczysc" Style="{StaticResource Przycisk}" Content="Wyczyść oznaczenia" Margin="0,0,8,0"/>
            <Button x:Name="btnZeruj" Style="{StaticResource Przycisk}" Content="Zeruj liczniki"/>
          </StackPanel>
          <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
            <Button x:Name="btnAnuluj" Style="{StaticResource Przycisk}" IsCancel="True" Content="Anuluj" Margin="0,0,8,0"/>
            <Button x:Name="btnZapisz" Style="{StaticResource PrzyciskGlowny}" Content="Zapisz"/>
          </StackPanel>
        </DockPanel>
      </StackPanel>
    </Border>
  </Grid>
</Window>
'@
    $dlg = Nowe-Okno $xaml
    Nazwane $dlg $xaml
    $dlg.Owner = $script:okno

    $widok = @{ Sort = 'plik'; Filtr = '*' }
    $etykiety = @(@{ Stan = ''; Tekst = 'Uczę się' }, @{ Stan = 'U'; Tekst = 'Umiem' }, @{ Stan = 'P'; Tekst = 'Powtórka' })

    $odswiezWiersz = {
        param($d)
        $d.Ramka.Background = Zasob $(switch ($d.Stan) { 'U' { 'ZielonyJasny' } 'P' { 'PomaranczowyJasny' } default { 'TloKarty' } })
        for ($k = 0; $k -lt 3; $k++) {
            $b = $d.Segmenty[$k]
            if ($etykiety[$k].Stan -eq $d.Stan) {
                switch ($d.Stan) {
                    'U' { $b.Background = Zasob 'Zielony'; $b.Foreground = [Windows.Media.Brushes]::White }
                    'P' { $b.Background = Zasob 'Pomaranczowy'; $b.Foreground = [Windows.Media.Brushes]::White }
                    default { $b.Background = Zasob 'TloKarty'; $b.Foreground = Zasob 'Tekst' }
                }
            } else { $b.Background = Zasob 'Przezroczysty'; $b.Foreground = Zasob 'TekstSlaby' }
        }
        if ($d.Ile -gt 0) {
            $d.Licznik.Text = "×$($d.Ile)"; $d.Licznik.Foreground = Zasob 'TekstSlaby'; $d.LicznikTlo.Background = Zasob 'TloPola'
        } else {
            $d.Licznik.Text = 'nowe'; $d.Licznik.Foreground = Zasob 'Akcent'; $d.LicznikTlo.Background = Zasob 'AkcentJasny'
        }
    }

    $podsumuj = {
        $n = $dane.Count
        $u = @($dane | Where-Object { $_.Stan -eq 'U' }).Count
        $p = @($dane | Where-Object { $_.Stan -eq 'P' }).Count
        $zrob = @($dane | Where-Object { $_.Ile -gt 0 }).Count
        $lblSuma.Text = "Wszystkich: $n   ·   Umiem: $u   ·   Powtórka: $p   ·   Do nauki: $($n - $u)`n" +
                        "Były już w dyktandzie: $zrob   ·   Jeszcze nie było: $($n - $zrob)"
    }

    $dane = @()
    for ($i = 0; $i -lt $slowka.Count; $i++) {
        $w = $slowka[$i]
        $d = @{ Slowo = $w; Stan = [string]$script:oznaczenia[$w]; Ile = (Ile-Razy $w); Poz = $i }

        $ramka = New-Object Windows.Controls.Border
        $ramka.CornerRadius = 12
        $ramka.BorderThickness = 1
        $ramka.BorderBrush = Zasob 'Linia'
        $ramka.Padding = Margines 16 8 8 8
        $ramka.Margin = Margines 0 0 4 6

        $g = New-Object Windows.Controls.Grid
        foreach ($s in '*', 'Auto', 'Auto') { [void]$g.ColumnDefinitions.Add((Nowa-Kolumna $s)) }
        [void]$g.Children.Add((Nowy-Tekst $w 16 'Tekst' -Gruby))

        $lt = New-Object Windows.Controls.Border
        $lt.CornerRadius = 10
        $lt.Padding = Margines 9 2 9 3
        $lt.Margin = Margines 0 0 12 0
        $lt.VerticalAlignment = 'Center'
        $lt.ToolTip = 'Ile razy słówko było w dyktandzie'
        $lc = Nowy-Tekst '' 12 'TekstSlaby' -Gruby
        $lt.Child = $lc
        [Windows.Controls.Grid]::SetColumn($lt, 1)
        [void]$g.Children.Add($lt)

        $seg = New-Object Windows.Controls.Border
        $seg.Style = Zasob 'Segmenty'
        $seg.CornerRadius = 10
        $segPanel = New-Object Windows.Controls.StackPanel
        $segPanel.Orientation = 'Horizontal'
        $przyciski = @()
        foreach ($e in $etykiety) {
            $b = New-Object Windows.Controls.Button
            $b.Style = Zasob 'Segment'
            $b.Content = $e.Tekst
            $b.Tag = "$i|$($e.Stan)"
            $b.Add_Click({
                param($s, $ev)
                $c = ([string]$s.Tag).Split('|')
                $d = $dane[[int]$c[0]]
                $d.Stan = $c[1]
                & $odswiezWiersz $d; & $podsumuj
            })
            [void]$segPanel.Children.Add($b)
            $przyciski += $b
        }
        $seg.Child = $segPanel
        [Windows.Controls.Grid]::SetColumn($seg, 2)
        [void]$g.Children.Add($seg)

        $ramka.Child = $g
        $d.Ramka = $ramka; $d.Segmenty = $przyciski; $d.Licznik = $lc; $d.LicznikTlo = $lt
        $dane += $d
        & $odswiezWiersz $d
    }

    $odswiezListe = {
        $szukaj = $txtSzukaj.Text.Trim()
        $widoczne = @($dane | Where-Object {
            ($widok.Filtr -eq '*' -or $_.Stan -eq $widok.Filtr) -and
            ($szukaj -eq '' -or $_.Slowo.IndexOf($szukaj, [StringComparison]::CurrentCultureIgnoreCase) -ge 0)
        })
        switch ($widok.Sort) {
            'az'  { $widoczne = @($widoczne | Sort-Object { $_.Slowo }) }
            'ile' { $widoczne = @($widoczne | Sort-Object @{ Expression = { $_.Ile }; Descending = $true }, @{ Expression = { $_.Poz } }) }
            default { $widoczne = @($widoczne | Sort-Object { $_.Poz }) }
        }
        $panelWierszy.Children.Clear()
        foreach ($d in $widoczne) { [void]$panelWierszy.Children.Add($d.Ramka) }
        $lblPusto.Visibility = if ($widoczne.Count -eq 0) { 'Visible' } else { 'Collapsed' }
        foreach ($b in $sortPlik, $sortAZ, $sortIle) {
            if ($b.Tag -eq $widok.Sort) { $b.Background = Zasob 'TloKarty'; $b.Foreground = Zasob 'Akcent' }
            else { $b.Background = Zasob 'Przezroczysty'; $b.Foreground = Zasob 'TekstSlaby' }
        }
        foreach ($b in $filtrWszystkie, $filtrNauka, $filtrUmiem, $filtrPowtorka) {
            if ([string]$b.Tag -eq $widok.Filtr) { $b.Background = Zasob 'TloKarty'; $b.Foreground = Zasob 'Akcent' }
            else { $b.Background = Zasob 'Przezroczysty'; $b.Foreground = Zasob 'TekstSlaby' }
        }
    }

    foreach ($b in $sortPlik, $sortAZ, $sortIle) {
        $b.Add_Click({ param($s, $e) $widok.Sort = [string]$s.Tag; & $odswiezListe })
    }
    foreach ($b in $filtrWszystkie, $filtrNauka, $filtrUmiem, $filtrPowtorka) {
        $b.Add_Click({ param($s, $e) $widok.Filtr = [string]$s.Tag; & $odswiezListe })
    }
    $txtSzukaj.Add_TextChanged({ & $odswiezListe })

    $btnWyczysc.Add_Click({
        foreach ($d in $dane) { $d.Stan = ''; & $odswiezWiersz $d }
        & $podsumuj; & $odswiezListe
    })
    $btnZeruj.Add_Click({
        foreach ($d in $dane) { $d.Ile = 0; & $odswiezWiersz $d }
        & $podsumuj; & $odswiezListe
    })
    $btnZapisz.Add_Click({ $dlg.DialogResult = $true })

    & $podsumuj
    & $odswiezListe

    if ($dlg.ShowDialog() -eq $true) {
        $h = @{}; $l = @{}
        # zachowaj dane słówek, których chwilowo nie ma w pliku
        foreach ($k in $script:oznaczenia.Keys) { if ($slowka -notcontains $k) { $h[$k] = $script:oznaczenia[$k] } }
        foreach ($k in $script:licznik.Keys) { if ($slowka -notcontains $k) { $l[$k] = $script:licznik[$k] } }
        foreach ($d in $dane) {
            if ($d.Stan -eq 'U' -or $d.Stan -eq 'P') { $h[$d.Slowo] = $d.Stan }
            if ($d.Ile -gt 0) { $l[$d.Slowo] = [int]$d.Ile }
        }
        $script:oznaczenia = $h
        $script:licznik = $l
        Zapisz-Stan
        Odswiez-Dostepne
    }
}

# =====================================================================
#  Okno główne
# =====================================================================
$xamlGlowne = @'
<Window __NAGLOWEK__ Title="Dyktando" Width="960" Height="780" MinWidth="880" MinHeight="660"
        WindowStartupLocation="CenterScreen">
  <Window.Resources>__ZASOBY__</Window.Resources>
  <Grid Margin="28,22,28,26">
    <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>

    <!-- Nagłówek -->
    <DockPanel Margin="0,0,0,20">
      <StackPanel DockPanel.Dock="Right" Orientation="Horizontal" VerticalAlignment="Center">
        <Button x:Name="btnPlik" Style="{StaticResource Przycisk}" Margin="0,0,10,0"
                ToolTip="Otwiera plik slowka.txt w Notatniku – jedno słówko w każdej linii">
          <StackPanel Orientation="Horizontal">
            <TextBlock Style="{StaticResource Ikona}" FontSize="13" Text="&#xE70F;" Margin="0,0,8,0"/>
            <TextBlock Text="Edytuj słówka"/>
          </StackPanel>
        </Button>
        <Button x:Name="btnLista" Style="{StaticResource Przycisk}">
          <StackPanel Orientation="Horizontal">
            <TextBlock Style="{StaticResource Ikona}" FontSize="13" Text="&#xE8FD;" Margin="0,0,8,0"/>
            <TextBlock Text="Lista słówek"/>
          </StackPanel>
        </Button>
      </StackPanel>
      <StackPanel Orientation="Horizontal">
        <Border Width="52" Height="52" CornerRadius="15" Background="{StaticResource Akcent}">
          <TextBlock Style="{StaticResource Ikona}" Text="&#xE70F;" FontSize="24" Foreground="White" HorizontalAlignment="Center"/>
        </Border>
        <StackPanel Margin="14,0,0,0" VerticalAlignment="Center">
          <TextBlock Text="Dyktando" FontSize="27" FontWeight="Bold"/>
          <TextBlock Text="Posłuchaj słówka i zapisz je w zeszycie" Foreground="{StaticResource TekstSlaby}"/>
        </StackPanel>
      </StackPanel>
    </DockPanel>

    <!-- Statystyki -->
    <UniformGrid Grid.Row="1" Columns="4" Margin="-7,0,-7,20">
      <Border Style="{StaticResource Karta}" Padding="18,14" Margin="7">
        <StackPanel>
          <StackPanel Orientation="Horizontal">
            <Ellipse Width="9" Height="9" Fill="{StaticResource Tekst}" Margin="0,0,8,0" VerticalAlignment="Center"/>
            <TextBlock Text="Słówek w pliku" FontSize="13" Foreground="{StaticResource TekstSlaby}"/>
          </StackPanel>
          <TextBlock x:Name="lblStatWszystkie" Text="0" FontSize="26" FontWeight="Bold" Margin="0,2,0,0"/>
          <TextBlock x:Name="lblStatWszystkieOpis" FontSize="12" Foreground="{StaticResource TekstSlaby}"/>
        </StackPanel>
      </Border>
      <Border Style="{StaticResource Karta}" Padding="18,14" Margin="7">
        <StackPanel>
          <StackPanel Orientation="Horizontal">
            <Ellipse Width="9" Height="9" Fill="{StaticResource Zielony}" Margin="0,0,8,0" VerticalAlignment="Center"/>
            <TextBlock Text="Umiem" FontSize="13" Foreground="{StaticResource TekstSlaby}"/>
          </StackPanel>
          <TextBlock x:Name="lblStatUmiem" Text="0" FontSize="26" FontWeight="Bold" Foreground="{StaticResource Zielony}" Margin="0,2,0,0"/>
          <TextBlock x:Name="lblStatUmiemOpis" FontSize="12" Foreground="{StaticResource TekstSlaby}"/>
        </StackPanel>
      </Border>
      <Border Style="{StaticResource Karta}" Padding="18,14" Margin="7">
        <StackPanel>
          <StackPanel Orientation="Horizontal">
            <Ellipse Width="9" Height="9" Fill="{StaticResource Pomaranczowy}" Margin="0,0,8,0" VerticalAlignment="Center"/>
            <TextBlock Text="Do powtórki" FontSize="13" Foreground="{StaticResource TekstSlaby}"/>
          </StackPanel>
          <TextBlock x:Name="lblStatPowtorka" Text="0" FontSize="26" FontWeight="Bold" Foreground="{StaticResource Pomaranczowy}" Margin="0,2,0,0"/>
          <TextBlock Text="zawsze są w teście" FontSize="12" Foreground="{StaticResource TekstSlaby}"/>
        </StackPanel>
      </Border>
      <Border Style="{StaticResource Karta}" Padding="18,14" Margin="7">
        <StackPanel>
          <StackPanel Orientation="Horizontal">
            <Ellipse Width="9" Height="9" Fill="{StaticResource Akcent}" Margin="0,0,8,0" VerticalAlignment="Center"/>
            <TextBlock Text="Jeszcze nie było" FontSize="13" Foreground="{StaticResource TekstSlaby}"/>
          </StackPanel>
          <TextBlock x:Name="lblStatNowe" Text="0" FontSize="26" FontWeight="Bold" Foreground="{StaticResource Akcent}" Margin="0,2,0,0"/>
          <TextBlock x:Name="lblStatNoweOpis" FontSize="12" Foreground="{StaticResource TekstSlaby}"/>
        </StackPanel>
      </Border>
    </UniformGrid>

    <Grid Grid.Row="2">
      <Grid.ColumnDefinitions><ColumnDefinition Width="320"/><ColumnDefinition Width="20"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>

      <!-- Ustawienia -->
      <Border x:Name="kartaUstawien" Style="{StaticResource Karta}">
        <ScrollViewer VerticalScrollBarVisibility="Auto">
        <StackPanel>
          <StackPanel Orientation="Horizontal" Margin="0,0,0,16">
            <TextBlock Style="{StaticResource Ikona}" Text="&#xE713;" Foreground="{StaticResource Akcent}" Margin="0,0,10,0"/>
            <TextBlock Text="Ustawienia" FontSize="17" FontWeight="Bold"/>
          </StackPanel>

          <DockPanel>
            <TextBlock x:Name="lblTempo" DockPanel.Dock="Right" FontWeight="SemiBold" Foreground="{StaticResource Akcent}"/>
            <TextBlock Text="Tempo czytania"/>
          </DockPanel>
          <Slider x:Name="sldTempo" Style="{StaticResource Suwak}" Minimum="-10" Maximum="10" Value="-2" Margin="0,8,0,0"/>
          <DockPanel Margin="0,1,0,0">
            <TextBlock DockPanel.Dock="Right" Text="szybciej" FontSize="12" Foreground="{StaticResource TekstSlaby}"/>
            <TextBlock Text="wolniej" FontSize="12" Foreground="{StaticResource TekstSlaby}"/>
          </DockPanel>

          <Border Height="1" Background="{StaticResource Linia}" Margin="0,14"/>

          <Grid Margin="0,0,0,14">
            <Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition Width="122"/></Grid.ColumnDefinitions>
            <StackPanel VerticalAlignment="Center">
              <TextBlock Text="Przerwa po słówku"/>
              <TextBlock Text="w sekundach" FontSize="12" Foreground="{StaticResource TekstSlaby}"/>
            </StackPanel>
            <Border Grid.Column="1" Style="{StaticResource Licznik}">
              <Grid>
                <Grid.ColumnDefinitions><ColumnDefinition Width="36"/><ColumnDefinition/><ColumnDefinition Width="36"/></Grid.ColumnDefinitions>
                <RepeatButton x:Name="btnPrzerwaMinus" Style="{StaticResource Krok}" Content="&#xE738;"/>
                <TextBox x:Name="txtPrzerwa" Grid.Column="1" Style="{StaticResource PoleLiczby}"/>
                <RepeatButton x:Name="btnPrzerwaPlus" Grid.Column="2" Style="{StaticResource Krok}" Content="&#xE710;"/>
              </Grid>
            </Border>
          </Grid>

          <Grid Margin="0,0,0,14">
            <Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition Width="122"/></Grid.ColumnDefinitions>
            <StackPanel VerticalAlignment="Center">
              <TextBlock Text="Ilość słówek w teście"/>
              <TextBlock Text="+ wszystkie powtórki" FontSize="12" Foreground="{StaticResource TekstSlaby}"/>
            </StackPanel>
            <Border Grid.Column="1" Style="{StaticResource Licznik}">
              <Grid>
                <Grid.ColumnDefinitions><ColumnDefinition Width="36"/><ColumnDefinition/><ColumnDefinition Width="36"/></Grid.ColumnDefinitions>
                <RepeatButton x:Name="btnIloscMinus" Style="{StaticResource Krok}" Content="&#xE738;"/>
                <TextBox x:Name="txtIlosc" Grid.Column="1" Style="{StaticResource PoleLiczby}"/>
                <RepeatButton x:Name="btnIloscPlus" Grid.Column="2" Style="{StaticResource Krok}" Content="&#xE710;"/>
              </Grid>
            </Border>
          </Grid>

          <Grid>
            <Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition Width="122"/></Grid.ColumnDefinitions>
            <StackPanel VerticalAlignment="Center">
              <TextBlock Text="Ile razy czytać"/>
              <TextBlock Text="każde słówko" FontSize="12" Foreground="{StaticResource TekstSlaby}"/>
            </StackPanel>
            <Border Grid.Column="1" Style="{StaticResource Licznik}">
              <Grid>
                <Grid.ColumnDefinitions><ColumnDefinition Width="36"/><ColumnDefinition/><ColumnDefinition Width="36"/></Grid.ColumnDefinitions>
                <RepeatButton x:Name="btnPowtMinus" Style="{StaticResource Krok}" Content="&#xE738;"/>
                <TextBox x:Name="txtPowt" Grid.Column="1" Style="{StaticResource PoleLiczby}"/>
                <RepeatButton x:Name="btnPowtPlus" Grid.Column="2" Style="{StaticResource Krok}" Content="&#xE710;"/>
              </Grid>
            </Border>
          </Grid>

          <Border Height="1" Background="{StaticResource Linia}" Margin="0,14"/>

          <CheckBox x:Name="chkLosowo" Style="{StaticResource Przelacznik}" IsChecked="True">
            <StackPanel>
              <TextBlock Text="Losowa kolejność"/>
              <TextBlock Text="słówka w przypadkowej kolejności" FontSize="12" Foreground="{StaticResource TekstSlaby}"/>
            </StackPanel>
          </CheckBox>
        </StackPanel>
        </ScrollViewer>
      </Border>

      <!-- Dyktando -->
      <Border Grid.Column="2" Style="{StaticResource Karta}" Padding="26,22">
        <Grid>
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/><RowDefinition Height="*"/>
          </Grid.RowDefinitions>

          <Grid>
            <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition/></Grid.ColumnDefinitions>
            <Grid Width="80" Height="80">
              <Ellipse x:Name="kolkoMowy" Fill="{StaticResource AkcentJasny}"/>
              <TextBlock x:Name="ikonaMowy" Style="{StaticResource Ikona}" Text="&#xE767;" FontSize="32"
                         Foreground="{StaticResource Akcent}" HorizontalAlignment="Center" Opacity="0.45"/>
            </Grid>
            <StackPanel Grid.Column="1" Margin="20,0,0,0" VerticalAlignment="Center">
              <TextBlock x:Name="lblStatus" Text="Gotowy" FontSize="30" FontWeight="Bold" TextTrimming="CharacterEllipsis"/>
              <TextBlock x:Name="lblPodstatus" Text="Naciśnij Start, aby rozpocząć dyktando" Foreground="{StaticResource TekstSlaby}"
                         TextWrapping="Wrap" Margin="0,2,0,0"/>
            </StackPanel>
          </Grid>

          <ProgressBar x:Name="pasek" Grid.Row="1" Style="{StaticResource Postep}" Maximum="1" Value="0" Margin="0,20,0,20"/>

          <Button x:Name="btnStart" Grid.Row="2" Style="{StaticResource PrzyciskGlowny}" Height="56" FontSize="17">
            <StackPanel Orientation="Horizontal">
              <TextBlock Style="{StaticResource Ikona}" Text="&#xE768;" FontSize="16" Margin="0,0,10,0"/>
              <TextBlock Text="Start – nowy test"/>
            </StackPanel>
          </Button>

          <UniformGrid Grid.Row="3" Columns="3" Margin="-5,10,-5,0">
            <Button x:Name="btnPauza" Style="{StaticResource Przycisk}" Margin="5" Height="46" IsEnabled="False">
              <StackPanel Orientation="Horizontal">
                <TextBlock x:Name="ikonaPauzy" Style="{StaticResource Ikona}" FontSize="13" Text="&#xE769;" Margin="0,0,8,0"/>
                <TextBlock x:Name="txtPauza" Text="Pauza"/>
              </StackPanel>
            </Button>
            <Button x:Name="btnPowtorz" Style="{StaticResource Przycisk}" Margin="5" Height="46" IsEnabled="False"
                    ToolTip="Przeczytaj jeszcze raz bieżące słówko">
              <StackPanel Orientation="Horizontal">
                <TextBlock Style="{StaticResource Ikona}" FontSize="13" Text="&#xE8EE;" Margin="0,0,8,0"/>
                <TextBlock Text="Powtórz"/>
              </StackPanel>
            </Button>
            <Button x:Name="btnStop" Style="{StaticResource Przycisk}" Margin="5" Height="46" IsEnabled="False">
              <StackPanel Orientation="Horizontal">
                <TextBlock Style="{StaticResource Ikona}" FontSize="13" Text="&#xE71A;" Margin="0,0,8,0"/>
                <TextBlock Text="Stop"/>
              </StackPanel>
            </Button>
          </UniformGrid>

          <Grid Grid.Row="4" Margin="0,20,0,0">
            <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
            <DockPanel Margin="0,0,0,10">
              <Button x:Name="btnSprawdz" DockPanel.Dock="Right" Style="{StaticResource PrzyciskZielony}" Padding="14,8"
                      VerticalAlignment="Center" IsEnabled="False">
                <StackPanel Orientation="Horizontal">
                  <TextBlock Style="{StaticResource Ikona}" FontSize="13" Text="&#xE73E;" Margin="0,0,8,0"/>
                  <TextBlock Text="Sprawdź dyktando"/>
                </StackPanel>
              </Button>
              <StackPanel VerticalAlignment="Center" Margin="0,0,12,0">
                <TextBlock x:Name="lblWynikTytul" Text="Słówka z dyktanda" FontSize="16" FontWeight="Bold"/>
                <TextBlock x:Name="lblWynikOpis" Text="Pojawią się tutaj po zakończeniu testu" FontSize="12"
                           Foreground="{StaticResource TekstSlaby}" TextWrapping="Wrap"/>
              </StackPanel>
            </DockPanel>
            <Border Grid.Row="1" Background="{StaticResource TloPola}" CornerRadius="12" Padding="12,12,6,6">
              <Grid>
                <ScrollViewer VerticalScrollBarVisibility="Auto">
                  <WrapPanel x:Name="panelSlowek"/>
                </ScrollViewer>
                <TextBlock x:Name="lblOstrzezenie" Foreground="{StaticResource Czerwony}" FontWeight="SemiBold"
                           TextWrapping="Wrap" Visibility="Collapsed" Margin="4,0,8,6"/>
              </Grid>
            </Border>
          </Grid>
        </Grid>
      </Border>
    </Grid>
  </Grid>
</Window>
'@

$script:okno = Nowe-Okno $xamlGlowne
Nazwane $script:okno $xamlGlowne

# --- Pola liczbowe z przyciskami - / + ---
$script:liczniki = @{}

function Ustaw-Licznik($nazwa, [int]$v) {
    $l = $script:liczniki[$nazwa]
    $v = [Math]::Max($l.Min, [Math]::Min($l.Max, $v))
    $l.Wartosc = $v
    $l.Pole.Text = "$v"
}

function Zatwierdz-Pole($pole) {
    $n = 0
    if ([int]::TryParse($pole.Text.Trim(), [ref]$n)) { Ustaw-Licznik $pole.Tag $n }
    else { Ustaw-Licznik $pole.Tag $script:liczniki[$pole.Tag].Wartosc }
}

function Licznik($nazwa) { return [int]$script:liczniki[$nazwa].Wartosc }

function Podlacz-Licznik($nazwa, $min, $max, $start) {
    $pole = $script:okno.FindName("txt$nazwa")
    $script:liczniki[$nazwa] = @{ Min = $min; Max = $max; Wartosc = $start; Pole = $pole }
    $minus = $script:okno.FindName("btn${nazwa}Minus")
    $plus = $script:okno.FindName("btn${nazwa}Plus")
    $minus.Tag = $nazwa; $plus.Tag = $nazwa; $pole.Tag = $nazwa
    $minus.Add_Click({ param($s, $e) Ustaw-Licznik $s.Tag ((Licznik $s.Tag) - 1) })
    $plus.Add_Click({ param($s, $e) Ustaw-Licznik $s.Tag ((Licznik $s.Tag) + 1) })
    $pole.Add_LostFocus({ param($s, $e) Zatwierdz-Pole $s })
    $pole.Add_KeyDown({ param($s, $e) if ($e.Key -eq 'Enter') { Zatwierdz-Pole $s; $s.SelectAll() } })
    $pole.Add_PreviewMouseWheel({
        param($s, $e)
        $krok = if ($e.Delta -gt 0) { 1 } else { -1 }
        Ustaw-Licznik $s.Tag ((Licznik $s.Tag) + $krok)
        $e.Handled = $true
    })
    Ustaw-Licznik $nazwa $start
}

Podlacz-Licznik 'Przerwa' 1 120 8
Podlacz-Licznik 'Ilosc' 1 1000 10
Podlacz-Licznik 'Powt' 1 5 2

# --- Tempo ---
function Tempo { return [int]$sldTempo.Value }
$aktualizujTempo = {
    $v = Tempo
    $opis = if ($v -le -6) { 'bardzo wolno' } elseif ($v -lt 0) { 'wolno' } elseif ($v -eq 0) { 'normalnie' } elseif ($v -le 5) { 'szybko' } else { 'bardzo szybko' }
    $znak = if ($v -gt 0) { "+$v" } elseif ($v -lt 0) { "−$(-$v)" } else { '0' }
    $lblTempo.Text = "$opis  ($znak)"
}
$sldTempo.Add_ValueChanged($aktualizujTempo)
& $aktualizujTempo

# --- Stan testu ---
$script:stan = @{
    Aktywny     = $false
    Pauza       = $false
    Lista       = @()
    Indeks      = 0
    Powtorzenie = 0
    CzekajDo    = [datetime]::MinValue
    PoMowie     = $false
    Policzone   = @{}
}

function Odswiez-Dostepne {
    $wszystkie = Wczytaj-Slowka
    $n = $wszystkie.Count
    $u = @($wszystkie | Where-Object { $script:oznaczenia[$_] -eq 'U' }).Count
    $p = @($wszystkie | Where-Object { $script:oznaczenia[$_] -eq 'P' }).Count
    $zrob = @($wszystkie | Where-Object { (Ile-Razy $_) -gt 0 }).Count
    $nowe = @($wszystkie | Where-Object { (Ile-Razy $_) -eq 0 -and $script:oznaczenia[$_] -ne 'U' }).Count
    $lblStatWszystkie.Text = "$n"
    $lblStatWszystkieOpis.Text = "do nauki: $($n - $u)"
    $lblStatUmiem.Text = "$u"
    $lblStatUmiemOpis.Text = if ($n -gt 0) { "{0}% wszystkich słówek" -f [Math]::Round(100 * $u / $n) } else { '' }
    $lblStatPowtorka.Text = "$p"
    $lblStatNowe.Text = "$nowe"
    $lblStatNoweOpis.Text = "były już: $zrob z $n"

    $ostrzezenia = @()
    if (-not $glosPL) { $ostrzezenia += 'Uwaga: nie znaleziono polskiego głosu w systemie (Ustawienia → Czas i język → Mowa).' }
    if ($n -eq 0) { $ostrzezenia += "Brak słówek w pliku: $plikSlowek" }
    $lblOstrzezenie.Text = $ostrzezenia -join "`n"
    $lblOstrzezenie.Visibility = if ($ostrzezenia.Count -gt 0 -and $panelSlowek.Children.Count -eq 0) { 'Visible' } else { 'Collapsed' }
}

# Kolorowe "kafelki" ze słówkami z testu (wyniki: numer wiersza -> 'ok'/'zle')
function Pokaz-Chipy($lista, $wyniki = @{}) {
    $panelSlowek.Children.Clear()
    $lblOstrzezenie.Visibility = 'Collapsed'
    for ($i = 0; $i -lt $lista.Count; $i++) {
        $r = $wyniki[$i]
        $b = New-Object Windows.Controls.Border
        $b.CornerRadius = 16
        $b.BorderThickness = 1
        $b.Padding = Margines 12 5 13 6
        $b.Margin = Margines 0 0 6 6
        switch ($r) {
            'ok'    { $b.Background = Zasob 'ZielonyJasny'; $b.BorderBrush = Zasob 'Zielony'; $kol = 'Zielony' }
            'zle'   { $b.Background = Zasob 'CzerwonyJasny'; $b.BorderBrush = Zasob 'Czerwony'; $kol = 'Czerwony' }
            default { $b.Background = Zasob 'TloKarty'; $b.BorderBrush = Zasob 'Linia'; $kol = 'Tekst' }
        }
        $t = New-Object Windows.Controls.TextBlock
        $t.FontSize = 15
        $r1 = New-Object Windows.Documents.Run("$($i + 1).  ")
        $r1.Foreground = Zasob 'TekstSlaby'
        $r2 = New-Object Windows.Documents.Run($lista[$i])
        $r2.FontWeight = [Windows.FontWeights]::SemiBold
        $r2.Foreground = Zasob $kol
        $t.Inlines.Add($r1)
        $t.Inlines.Add($r2)
        $b.Child = $t
        [void]$panelSlowek.Children.Add($b)
    }
}

function Pokaz-Liste-Testu {
    $lista = @($script:stan.Lista)
    Pokaz-Chipy $lista
    $lblWynikTytul.Text = "Słówka z dyktanda ($($lista.Count))"
    $lblWynikOpis.Text = 'Porównaj z zeszytem i kliknij „Sprawdź dyktando”'
}

function Ustaw-Przyciski($aktywny) {
    $btnPauza.IsEnabled = $aktywny
    $btnStop.IsEnabled = $aktywny
    $btnPowtorz.IsEnabled = $aktywny
    $btnStart.IsEnabled = -not $aktywny
    $kartaUstawien.IsEnabled = -not $aktywny
    $btnLista.IsEnabled = -not $aktywny
    $btnPlik.IsEnabled = -not $aktywny
}

function Ustaw-Pauze($pauza) {
    if ($pauza) { $txtPauza.Text = 'Wznów'; $ikonaPauzy.Text = [string][char]0xE768 }
    else { $txtPauza.Text = 'Pauza'; $ikonaPauzy.Text = [string][char]0xE769 }
}

function Zakoncz-Test($komunikat, $opis) {
    $script:stan.Aktywny = $false
    $script:stan.Pauza = $false
    $synth.SpeakAsyncCancelAll()
    Ustaw-Pauze $false
    Ustaw-Przyciski $false
    $lblStatus.Text = $komunikat
    $lblPodstatus.Text = $opis
    $btnSprawdz.IsEnabled = ($script:stan.Lista.Count -gt 0)
    Zapisz-Stan
    Odswiez-Dostepne
}

function Mow($tekst) {
    $synth.Rate = Tempo
    [void]$synth.SpeakAsync($tekst)
    $script:stan.PoMowie = $true
}

# --- Timer sterujący dyktandem ---
$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(100)
$timer.Add_Tick({
    $mowi = ($synth.State -eq [System.Speech.Synthesis.SynthesizerState]::Speaking)
    $ikonaMowy.Opacity = if ($mowi) { 1 } else { 0.45 }
    $kolkoMowy.Fill = Zasob $(if ($mowi) { 'AkcentJasny' } else { 'TloPola' })

    $s = $script:stan
    if (-not $s.Aktywny -or $s.Pauza) { return }
    if ($synth.State -ne [System.Speech.Synthesis.SynthesizerState]::Ready) { return }

    if ($s.PoMowie) {
        # Właśnie skończyło mówić - odczekaj przerwę
        $s.PoMowie = $false
        $ostatnieCzytanie = ($s.Powtorzenie -ge (Licznik 'Powt'))
        if ($ostatnieCzytanie) {
            $s.CzekajDo = (Get-Date).AddSeconds((Licznik 'Przerwa'))
            $lblPodstatus.Text = 'Zapisz słówko w zeszycie'
        } else {
            $s.CzekajDo = (Get-Date).AddSeconds(2)   # krótka przerwa między powtórzeniami
        }
        return
    }

    if ((Get-Date) -lt $s.CzekajDo) { return }

    if ($s.Powtorzenie -ge (Licznik 'Powt')) {
        $s.Indeks++
        $s.Powtorzenie = 0
        $pasek.Value = $s.Indeks / [Math]::Max(1, $s.Lista.Count)
    }

    if ($s.Indeks -ge $s.Lista.Count) {
        Zakoncz-Test 'Koniec dyktanda!' 'Sprawdź, jak Ci poszło'
        $pasek.Value = 1
        [void]$synth.SpeakAsync('Koniec dyktanda.')
        # Pokaż słówka z testu do sprawdzenia
        $timer.Stop()
        Pokaz-Liste-Testu
        Sprawdz-Test
        $timer.Start()
        return
    }

    $lblStatus.Text = "Słówko $($s.Indeks + 1) z $($s.Lista.Count)"
    $s.Powtorzenie++
    $lblPodstatus.Text = if ((Licznik 'Powt') -gt 1) { "Słuchaj uważnie… (czytanie $($s.Powtorzenie) z $(Licznik 'Powt'))" } else { 'Słuchaj uważnie…' }
    if ($s.Powtorzenie -eq 1 -and -not $s.Policzone.ContainsKey($s.Indeks)) {
        # słówko przeczytane w dyktandzie - zwiększ licznik
        $w = $s.Lista[$s.Indeks]
        $script:licznik[$w] = (Ile-Razy $w) + 1
        $s.Policzone[$s.Indeks] = $true
    }
    Mow $s.Lista[$s.Indeks]
})

# --- Obsługa przycisków ---
$btnStart.Add_Click({
    foreach ($n in 'Przerwa', 'Ilosc', 'Powt') { Zatwierdz-Pole $script:liczniki[$n].Pole }
    $slowka = Wczytaj-Slowka
    Odswiez-Dostepne
    if ($slowka.Count -eq 0) {
        Komunikat "Brak słówek w pliku:`n$plikSlowek`n`nKliknij „Edytuj słówka”, aby je dopisać (jedno w linii)."
        return
    }
    # Pomijamy słówka "umiem"; słówka "powtórka" są zawsze w teście
    $doNauki = @($slowka | Where-Object { $script:oznaczenia[$_] -ne 'U' })
    if ($doNauki.Count -eq 0) {
        Komunikat 'Wszystkie słówka są oznaczone jako „Umiem”. Zmień oznaczenia w „Lista słówek”.'
        return
    }
    $powtorki = @($doNauki | Where-Object { $script:oznaczenia[$_] -eq 'P' })
    $pozostale = @($doNauki | Where-Object { $script:oznaczenia[$_] -ne 'P' })
    $ile = [Math]::Max([Math]::Min((Licznik 'Ilosc'), $doNauki.Count), $powtorki.Count)
    $brakuje = $ile - $powtorki.Count
    # Uzupełnienie: najpierw słówka, których jeszcze nie było, potem te z najmniejszą liczbą powtórzeń
    $kolejnosc = @{}
    for ($i = 0; $i -lt $slowka.Count; $i++) { $kolejnosc[$slowka[$i]] = $i }
    $losowo = [bool]$chkLosowo.IsChecked
    if ($losowo) { $remis = { Get-Random } } else { $remis = { $kolejnosc[$_] } }
    $dodatkowe = @(if ($brakuje -gt 0) {
        $pozostale | Sort-Object @{ Expression = { Ile-Razy $_ } }, @{ Expression = $remis } | Select-Object -First $brakuje
    })
    $wybrane = @($powtorki + $dodatkowe)
    if ($losowo) {
        $lista = @($wybrane | Get-Random -Count $wybrane.Count)
    } else {
        $lista = @($doNauki | Where-Object { $wybrane -contains $_ })
    }
    $nowe = @($lista | Where-Object { (Ile-Razy $_) -eq 0 }).Count

    $synth.SpeakAsyncCancelAll()
    $script:stan.Lista = $lista
    $script:stan.Indeks = 0
    $script:stan.Powtorzenie = 0
    $script:stan.PoMowie = $false
    $script:stan.Policzone = @{}
    $script:stan.Pauza = $false
    $script:stan.CzekajDo = (Get-Date).AddSeconds(2)
    $script:stan.Aktywny = $true

    $panelSlowek.Children.Clear()
    $lblOstrzezenie.Visibility = 'Collapsed'
    $lblWynikTytul.Text = 'Słówka z dyktanda'
    $lblWynikOpis.Text = 'Pojawią się tutaj po zakończeniu testu'
    $btnSprawdz.IsEnabled = $false
    $pasek.Value = 0
    Ustaw-Pauze $false
    Ustaw-Przyciski $true
    $lblStatus.Text = 'Przygotuj się…'
    $lblPodstatus.Text = "$ile słówek w teście, w tym nowych: $nowe"
    $synth.Rate = Tempo
    [void]$synth.SpeakAsync('Zaczynamy dyktando.')
    $script:stan.PoMowie = $false
})

$btnPauza.Add_Click({
    $s = $script:stan
    if (-not $s.Aktywny) { return }
    if ($s.Pauza) {
        $s.Pauza = $false
        Ustaw-Pauze $false
        $s.CzekajDo = (Get-Date).AddSeconds(1)
        $lblStatus.Text = "Słówko $([Math]::Min($s.Indeks + 1, $s.Lista.Count)) z $($s.Lista.Count)"
        $lblPodstatus.Text = 'Wznawiam…'
    } else {
        $s.Pauza = $true
        $synth.SpeakAsyncCancelAll()
        # słówko przerwane - przeczytaj je od nowa po wznowieniu
        if ($s.PoMowie -and $s.Powtorzenie -gt 0) { $s.Powtorzenie-- }
        $s.PoMowie = $false
        Ustaw-Pauze $true
        $lblStatus.Text = 'Pauza'
        $lblPodstatus.Text = 'Kliknij „Wznów”, aby kontynuować'
    }
})

$btnStop.Add_Click({ Zakoncz-Test 'Test zatrzymany' 'Możesz sprawdzić przeczytane słówka lub zacząć od nowa' })

$btnPowtorz.Add_Click({
    $s = $script:stan
    if (-not $s.Aktywny -or $s.Indeks -ge $s.Lista.Count -or $s.Powtorzenie -eq 0) { return }
    $synth.SpeakAsyncCancelAll()
    $synth.Rate = Tempo
    [void]$synth.SpeakAsync($s.Lista[$s.Indeks])
    $s.PoMowie = $true
})

$btnSprawdz.Add_Click({
    Pokaz-Liste-Testu
    Sprawdz-Test
})

$btnLista.Add_Click({ Pokaz-Liste-Slowek })

$btnPlik.Add_Click({
    if (-not (Test-Path $plikSlowek)) { [IO.File]::WriteAllText($plikSlowek, '', (New-Object Text.UTF8Encoding($false))) }
    Start-Process notepad.exe -ArgumentList "`"$plikSlowek`""
})

# Po powrocie do okna (np. z Notatnika) odśwież statystyki
$script:okno.Add_Activated({ if (-not $script:stan.Aktywny) { Odswiez-Dostepne } })

$script:okno.Add_Closing({
    $timer.Stop()
    if ($script:stan.Aktywny) { Zapisz-Stan }
    $synth.SpeakAsyncCancelAll()
    $synth.Dispose()
})

Odswiez-Dostepne
$timer.Start()
[void]$script:okno.ShowDialog()
