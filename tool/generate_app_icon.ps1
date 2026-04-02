Add-Type -AssemblyName System.Drawing

Add-Type -ReferencedAssemblies 'System.Drawing.dll' -TypeDefinition @"
using System;
using System.Drawing;
using System.Drawing.Drawing2D;

public static class IconGeometry
{
    public static GraphicsPath RoundedRect(float x, float y, float width, float height, float radius)
    {
        var diameter = radius * 2f;
        var rect = new RectangleF(x, y, width, height);
        var path = new GraphicsPath();

        path.AddArc(rect.X, rect.Y, diameter, diameter, 180, 90);
        path.AddArc(rect.Right - diameter, rect.Y, diameter, diameter, 270, 90);
        path.AddArc(rect.Right - diameter, rect.Bottom - diameter, diameter, diameter, 0, 90);
        path.AddArc(rect.X, rect.Bottom - diameter, diameter, diameter, 90, 90);
        path.CloseFigure();
        return path;
    }

    public static GraphicsPath SpeechBubble(float x, float y, float width, float height, float radius)
    {
        var path = RoundedRect(x, y, width, height, radius);
        path.AddPolygon(new[]
        {
            new PointF(x + width * 0.26f, y + height * 0.82f),
            new PointF(x + width * 0.14f, y + height * 1.10f),
            new PointF(x + width * 0.40f, y + height * 0.92f)
        });
        return path;
    }
}
"@

function New-Color {
  param(
    [string]$Hex,
    [int]$Alpha = 255
  )

  $clean = $Hex.TrimStart('#')
  $r = [Convert]::ToInt32($clean.Substring(0, 2), 16)
  $g = [Convert]::ToInt32($clean.Substring(2, 2), 16)
  $b = [Convert]::ToInt32($clean.Substring(4, 2), 16)
  return [System.Drawing.Color]::FromArgb($Alpha, $r, $g, $b)
}

function Fill-RoundedRect {
  param(
    [System.Drawing.Graphics]$Graphics,
    [System.Drawing.Brush]$Brush,
    [float]$X,
    [float]$Y,
    [float]$Width,
    [float]$Height,
    [float]$Radius
  )

  $path = [IconGeometry]::RoundedRect($X, $Y, $Width, $Height, $Radius)
  try {
    $Graphics.FillPath($Brush, $path)
  } finally {
    $path.Dispose()
  }
}

function Add-Glow {
  param(
    [System.Drawing.Graphics]$Graphics,
    [float]$CenterX,
    [float]$CenterY,
    [float]$Diameter,
    [string]$Hex,
    [int]$MaxAlpha = 80,
    [int]$Steps = 16
  )

  for ($index = 0; $index -lt $Steps; $index++) {
    $progress = if ($Steps -eq 1) { 1.0 } else { $index / ($Steps - 1.0) }
    $currentDiameter = $Diameter * (1.18 - ($progress * 0.72))
    $alpha = [Math]::Max(1, [int]($MaxAlpha * [Math]::Pow($progress, 1.8)))
    $brush = [System.Drawing.SolidBrush]::new((New-Color $Hex $alpha))
    try {
      $Graphics.FillEllipse(
        $brush,
        $CenterX - ($currentDiameter / 2),
        $CenterY - ($currentDiameter / 2),
        $currentDiameter,
        $currentDiameter
      )
    } finally {
      $brush.Dispose()
    }
  }
}

$outputPath = Join-Path $PSScriptRoot '..\assets\app_icon\app_icon.png'
$outputDirectory = Split-Path -Parent $outputPath
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null

$bitmap = [System.Drawing.Bitmap]::new(1024, 1024)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)

try {
  $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
  $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $graphics.Clear([System.Drawing.Color]::Transparent)

  $backgroundPath = [IconGeometry]::RoundedRect(42, 42, 940, 940, 228)
  try {
    $backgroundBrush = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
      [System.Drawing.PointF]::new(42, 42),
      [System.Drawing.PointF]::new(982, 982),
      (New-Color '#FFFDF9'),
      (New-Color '#FFE9D7')
    )
    try {
      $graphics.FillPath($backgroundBrush, $backgroundPath)
    } finally {
      $backgroundBrush.Dispose()
    }

    $graphics.SetClip($backgroundPath)

    Add-Glow -Graphics $graphics -CenterX 782 -CenterY 220 -Diameter 362 -Hex '#FFB446' -MaxAlpha 72 -Steps 18
    Add-Glow -Graphics $graphics -CenterX 226 -CenterY 348 -Diameter 276 -Hex '#6D95F4' -MaxAlpha 28 -Steps 14
    Add-Glow -Graphics $graphics -CenterX 844 -CenterY 774 -Diameter 220 -Hex '#5E9A75' -MaxAlpha 24 -Steps 12

    $waveBrush = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
      [System.Drawing.PointF]::new(140, 700),
      [System.Drawing.PointF]::new(900, 980),
      (New-Color '#FFA15E' 154),
      (New-Color '#F38765' 192)
    )
    try {
      $graphics.FillEllipse($waveBrush, -70, 692, 1188, 448)
    } finally {
      $waveBrush.Dispose()
    }

    $bubblePath = [IconGeometry]::SpeechBubble(254, 282, 516, 332, 148)
    try {
      $bubbleBrush = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
        [System.Drawing.PointF]::new(280, 300),
        [System.Drawing.PointF]::new(760, 650),
        (New-Color '#FF6A1A'),
        (New-Color '#FF9656')
      )
      try {
        $graphics.FillPath($bubbleBrush, $bubblePath)
      } finally {
        $bubbleBrush.Dispose()
      }
    } finally {
      $bubblePath.Dispose()
    }

    $highlightBrush = [System.Drawing.SolidBrush]::new((New-Color '#FFFFFF' 54))
    try {
      $graphics.FillEllipse($highlightBrush, 556, 326, 148, 86)
    } finally {
      $highlightBrush.Dispose()
    }

    $jadeBrush = [System.Drawing.SolidBrush]::new((New-Color '#5E9A75' 236))
    try {
      $graphics.FillEllipse($jadeBrush, 724, 332, 54, 54)
    } finally {
      $jadeBrush.Dispose()
    }

    $markBrush = [System.Drawing.SolidBrush]::new((New-Color '#FFF9F4' 232))
    try {
      Fill-RoundedRect -Graphics $graphics -Brush $markBrush -X 378 -Y 414 -Width 24 -Height 122 -Radius 12
      Fill-RoundedRect -Graphics $graphics -Brush $markBrush -X 420 -Y 384 -Width 24 -Height 182 -Radius 12
      Fill-RoundedRect -Graphics $graphics -Brush $markBrush -X 462 -Y 432 -Width 24 -Height 86 -Radius 12

      $triangle = [System.Drawing.Drawing2D.GraphicsPath]::new()
      try {
        $triangle.AddPolygon(@(
            [System.Drawing.PointF]::new(546, 406),
            [System.Drawing.PointF]::new(546, 560),
            [System.Drawing.PointF]::new(672, 483)
          ))
        $graphics.FillPath($markBrush, $triangle)
      } finally {
        $triangle.Dispose()
      }
    } finally {
      $markBrush.Dispose()
    }

    $graphics.ResetClip()
  } finally {
    $backgroundPath.Dispose()
  }

  $bitmap.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
} finally {
  $graphics.Dispose()
  $bitmap.Dispose()
}
