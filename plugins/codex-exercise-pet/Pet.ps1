param(
    [switch]$Preview,
    [string]$DataDirectory,
    [long]$WatchFromUtcTicks = [DateTime]::UtcNow.Ticks
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Runtime.ps1')
$runtime = Get-PetDataDirectory $DataDirectory
$active = Join-Path $runtime 'active'
$previewRequest = Join-Path $runtime 'preview.request'
[void][IO.Directory]::CreateDirectory($runtime)

$instance = [Threading.Mutex]::new($false, (Get-PetMutexName $runtime))
$ownsInstance = $false
try {
    try {
        $ownsInstance = $instance.WaitOne(0)
    } catch [Threading.AbandonedMutexException] {
        $ownsInstance = $true
    }
    if (-not $ownsInstance) {
        if ($Preview) { [IO.File]::WriteAllText($previewRequest, '') }
        return
    }

    Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
    Add-Type -AssemblyName System.Windows.Forms, System.Drawing
    $settingsFile = Join-Path $runtime 'settings.json'
    if (-not [IO.File]::Exists($settingsFile)) { $settingsFile = Join-Path $PSScriptRoot 'settings.json' }
    $settings = Get-Content -LiteralPath $settingsFile -Raw | ConvertFrom-Json
    $longCommandSeconds = [int]$settings.longCommandSeconds
    $cooldownSeconds = [int]$settings.cooldownSeconds
    if ($longCommandSeconds -lt 1 -or $cooldownSeconds -lt 0) {
        throw 'longCommandSeconds must be positive and cooldownSeconds must be non-negative.'
    }

    $app = New-Object Windows.Application
    $app.ShutdownMode = [Windows.ShutdownMode]::OnExplicitShutdown
    $xaml = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'Pet.xaml'))
    $window = [Windows.Markup.XamlReader]::Parse($xaml)
    $heading = $window.FindName('Heading')
    $detail = $window.FindName('Detail')
    $countdown = $window.FindName('Countdown')
    $mainButton = $window.FindName('MainButton')
    $dismissButton = $window.FindName('DismissButton')
    $scene = $window.FindName('Scene')
    $offset = $window.FindName('EntryOffset')

    $area = [Windows.SystemParameters]::WorkArea
    $window.Left = [Math]::Max($area.Left, $area.Right - $window.Width - 20)
    $window.Top = [Math]::Max($area.Top, $area.Bottom - $window.Height - 20)
    $stopwatch = New-Object Diagnostics.Stopwatch
    $poll = New-Object Windows.Threading.DispatcherTimer
    $poll.Interval = [TimeSpan]::FromMilliseconds(250)
    $timer = New-Object Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(100)
    $watchFrom = [DateTime]::new($WatchFromUtcTicks, [DateTimeKind]::Utc)
    $script:lastReminder = [DateTime]::MinValue
    $script:phase = 'hidden'

    function Hide-Reminder {
        $timer.Stop()
        $stopwatch.Reset()
        $window.Hide()
        $script:phase = 'hidden'
    }

    function Show-Reminder {
        if ($window.IsVisible) { return }
        $script:phase = 'ready'
        $heading.Text = '站起来伸展一下？'
        $detail.Text = '用 30 秒活动肩背，等会儿再回来。'
        $countdown.Visibility = 'Collapsed'
        $mainButton.Content = '开始'
        $mainButton.Visibility = 'Visible'
        $dismissButton.Content = '跳过'
        $window.Show()

        if ([Windows.SystemParameters]::ClientAreaAnimation) {
            $slide = New-Object Windows.Media.Animation.DoubleAnimation
            $slide.From = 34
            $slide.To = 0
            $slide.Duration = [Windows.Duration]::new([TimeSpan]::FromMilliseconds(370))
            $bounce = New-Object Windows.Media.Animation.BackEase
            $bounce.EasingMode = 'EaseOut'
            $bounce.Amplitude = 0.7
            $slide.EasingFunction = $bounce
            $offset.BeginAnimation([Windows.Media.TranslateTransform]::YProperty, $slide)

            $fade = New-Object Windows.Media.Animation.DoubleAnimation
            $fade.From = 0
            $fade.To = 1
            $fade.Duration = [Windows.Duration]::new([TimeSpan]::FromMilliseconds(170))
            $scene.BeginAnimation([Windows.UIElement]::OpacityProperty, $fade)
        }
    }

    $window.FindName('Header').Add_MouseLeftButtonDown({
        try { $window.DragMove() } catch [InvalidOperationException] {}
    })
    $window.FindName('PetHandle').Add_MouseLeftButtonDown({
        try { $window.DragMove() } catch [InvalidOperationException] {}
    })
    $window.Add_KeyDown({ param($sender, $keyEvent)
        if ($keyEvent.Key -eq 'Escape') { Hide-Reminder }
    })
    $dismissButton.Add_Click({ Hide-Reminder })
    $mainButton.Add_Click({
        if ($script:phase -ne 'ready') { return }
        $script:phase = 'stretching'
        $heading.Text = '向前伸展肩背'
        $detail.Text = '双手在胸前交扣，手心朝外轻轻前推。放松肩膀，自然呼吸。'
        $mainButton.Visibility = 'Collapsed'
        $dismissButton.Content = '结束'
        $countdown.Text = '00:30'
        $countdown.Visibility = 'Visible'
        $stopwatch.Restart()
        $timer.Start()
    })
    $timer.Add_Tick({
        $seconds = [int][Math]::Ceiling(30 - $stopwatch.Elapsed.TotalSeconds)
        if ($seconds -gt 0) {
            $countdown.Text = '00:{0:00}' -f $seconds
            return
        }
        $timer.Stop()
        $script:phase = 'complete'
        $heading.Text = '伸展完成'
        $detail.Text = '放下双手，活动一下肩膀，再回到 Codex。'
        $countdown.Text = '00:00'
        $dismissButton.Content = '完成'
    })

    $poll.Add_Tick({
        try {
            if ([IO.File]::Exists($previewRequest)) {
                [IO.File]::Delete($previewRequest)
                Show-Reminder
            }
            $now = [DateTime]::UtcNow
            if ($window.IsVisible -or ($now - $script:lastReminder).TotalSeconds -lt $cooldownSeconds) { return }
            if (-not [IO.Directory]::Exists($active)) { return }

            foreach ($marker in ([IO.DirectoryInfo]::new($active)).EnumerateFiles('*.run')) {
                $started = $marker.LastWriteTimeUtc
                if ($started -lt $watchFrom) {
                    # Left over from before this instance was started.
                    [IO.File]::Delete($marker.FullName)
                    continue
                }
                if (($now - $started).TotalSeconds -ge $longCommandSeconds -and [IO.File]::Exists($marker.FullName)) {
                    [IO.File]::Delete($marker.FullName)
                    $script:lastReminder = $now
                    Show-Reminder
                    break
                }
            }
        } catch [IO.IOException] {
            # A hook can remove a marker between enumeration and inspection.
        }
    })

    $menu = New-Object Windows.Forms.ContextMenuStrip
    $previewItem = $menu.Items.Add('预览提醒')
    $previewItem.Add_Click({ Show-Reminder })
    $exitItem = $menu.Items.Add('退出伸展兔')
    $exitItem.Add_Click({ $app.Shutdown() })
    $tray = New-Object Windows.Forms.NotifyIcon
    $tray.Text = 'Codex 伸展兔'
    $tray.Icon = [Drawing.SystemIcons]::Information
    $tray.ContextMenuStrip = $menu
    $tray.Add_DoubleClick({ Show-Reminder })
    $tray.Visible = $true

    $poll.Start()
    if ($Preview) { Show-Reminder }
    [void]$app.Run()
} catch {
    $failure = '{0:u} {1}{2}' -f [DateTime]::Now, ($_ | Out-String).Trim(), [Environment]::NewLine
    [IO.File]::AppendAllText((Join-Path $runtime 'pet-error.log'), $failure)
    throw
} finally {
    if ($null -ne $tray) {
        $tray.Visible = $false
        $tray.Dispose()
    }
    if ($null -ne $menu) { $menu.Dispose() }
    if ($ownsInstance) { $instance.ReleaseMutex() }
    $instance.Dispose()
}
