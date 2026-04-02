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

function Resize-Bitmap {
  param(
    [System.Drawing.Bitmap]$Source,
    [int]$Size
  )

  $target = [System.Drawing.Bitmap]::new($Size, $Size)
  $graphics = [System.Drawing.Graphics]::FromImage($target)
  try {
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.Clear([System.Drawing.Color]::Transparent)
    $graphics.DrawImage($Source, 0, 0, $Size, $Size)
  } finally {
    $graphics.Dispose()
  }
  return $target
}

function Save-Png {
  param(
    [System.Drawing.Bitmap]$Bitmap,
    [string]$Path
  )

  $directory = Split-Path -Parent $Path
  New-Item -ItemType Directory -Force -Path $directory | Out-Null
  $Bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
}

function Save-Ico {
  param(
    [System.Drawing.Bitmap]$Bitmap,
    [string]$Path
  )

  $directory = Split-Path -Parent $Path
  New-Item -ItemType Directory -Force -Path $directory | Out-Null

  $pngStream = [System.IO.MemoryStream]::new()
  try {
    $Bitmap.Save($pngStream, [System.Drawing.Imaging.ImageFormat]::Png)
    $pngBytes = $pngStream.ToArray()

    $fileStream = [System.IO.File]::Create($Path)
    try {
      $writer = [System.IO.BinaryWriter]::new($fileStream)
      try {
        $writer.Write([UInt16]0)
        $writer.Write([UInt16]1)
        $writer.Write([UInt16]1)
        $writer.Write([byte]0)
        $writer.Write([byte]0)
        $writer.Write([byte]0)
        $writer.Write([byte]0)
        $writer.Write([UInt16]1)
        $writer.Write([UInt16]32)
        $writer.Write([UInt32]$pngBytes.Length)
        $writer.Write([UInt32]22)
        $writer.Write($pngBytes)
      } finally {
        $writer.Dispose()
      }
    } finally {
      $fileStream.Dispose()
    }
  } finally {
    $pngStream.Dispose()
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
    [int]$Steps = 18
  )

  for ($index = 0; $index -lt $Steps; $index++) {
    $progress = if ($Steps -eq 1) { 1.0 } else { $index / ($Steps - 1.0) }
    $currentDiameter = $Diameter * (1.22 - ($progress * 0.74))
    $alpha = [Math]::Max(1, [int]($MaxAlpha * [Math]::Pow($progress, 1.7)))
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

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$assetIconPath = Join-Path $repoRoot 'assets\app_icon\app_icon.png'
$web512Path = Join-Path $repoRoot 'web\icons\Icon-512.png'
$web192Path = Join-Path $repoRoot 'web\icons\Icon-192.png'
$webMask512Path = Join-Path $repoRoot 'web\icons\Icon-maskable-512.png'
$webMask192Path = Join-Path $repoRoot 'web\icons\Icon-maskable-192.png'
$webFaviconPath = Join-Path $repoRoot 'web\favicon.png'
$windowsIcoPath = Join-Path $repoRoot 'windows\runner\resources\app_icon.ico'

$bitmap = [System.Drawing.Bitmap]::new(1024, 1024)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)

try {
  $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
  $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $graphics.Clear([System.Drawing.Color]::Transparent)

  $backgroundPath = [IconGeometry]::RoundedRect(42, 42, 940, 940, 232)
  try {
    $backgroundBrush = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
      [System.Drawing.PointF]::new(42, 42),
      [System.Drawing.PointF]::new(982, 982),
      (New-Color '#FFF9F1'),
      (New-Color '#FFD8BA')
    )
    try {
      $graphics.FillPath($backgroundBrush, $backgroundPath)
    } finally {
      $backgroundBrush.Dispose()
    }

    $graphics.SetClip($backgroundPath)

    Add-Glow -Graphics $graphics -CenterX 786 -CenterY 202 -Diameter 382 -Hex '#FFBD59' -MaxAlpha 76
    Add-Glow -Graphics $graphics -CenterX 248 -CenterY 300 -Diameter 248 -Hex '#8FC8D6' -MaxAlpha 28 -Steps 14
    Add-Glow -Graphics $graphics -CenterX 802 -CenterY 790 -Diameter 214 -Hex '#7FA77A' -MaxAlpha 22 -Steps 12

    $waveBrush = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
      [System.Drawing.PointF]::new(120, 720),
      [System.Drawing.PointF]::new(920, 980),
      (New-Color '#FFB171' 158),
      (New-Color '#F28A6D' 192)
    )
    try {
      $graphics.FillEllipse($waveBrush, -40, 708, 1120, 430)
    } finally {
      $waveBrush.Dispose()
    }

    $plateBrush = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
      [System.Drawing.PointF]::new(252, 188),
      [System.Drawing.PointF]::new(742, 742),
      (New-Color '#FFF6E7'),
      (New-Color '#FFD8A6')
    )
    try {
      $graphics.FillEllipse($plateBrush, 228, 170, 568, 568)
    } finally {
      $plateBrush.Dispose()
    }

    $cardBrush = [System.Drawing.SolidBrush]::new((New-Color '#FFFFFF' 44))
    try {
      Fill-RoundedRect -Graphics $graphics -Brush $cardBrush -X 284 -Y 214 -Width 456 -Height 420 -Radius 156
    } finally {
      $cardBrush.Dispose()
    }

    $sweaterBrush = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
      [System.Drawing.PointF]::new(312, 610),
      [System.Drawing.PointF]::new(708, 820),
      (New-Color '#5C8570'),
      (New-Color '#7AA088')
    )
    try {
      Fill-RoundedRect -Graphics $graphics -Brush $sweaterBrush -X 290 -Y 602 -Width 446 -Height 210 -Radius 112
    } finally {
      $sweaterBrush.Dispose()
    }

    $collarBrush = [System.Drawing.SolidBrush]::new((New-Color '#F6E9DD'))
    try {
      $graphics.FillEllipse($collarBrush, 424, 592, 92, 74)
      $graphics.FillEllipse($collarBrush, 508, 592, 92, 74)
    } finally {
      $collarBrush.Dispose()
    }

    $neckBrush = [System.Drawing.SolidBrush]::new((New-Color '#F0C4A3'))
    try {
      Fill-RoundedRect -Graphics $graphics -Brush $neckBrush -X 462 -Y 522 -Width 102 -Height 112 -Radius 30
    } finally {
      $neckBrush.Dispose()
    }

    $hairBackBrush = [System.Drawing.SolidBrush]::new((New-Color '#E7EDF3'))
    try {
      $graphics.FillEllipse($hairBackBrush, 320, 206, 390, 226)
      $graphics.FillEllipse($hairBackBrush, 318, 274, 110, 170)
      $graphics.FillEllipse($hairBackBrush, 602, 266, 104, 168)
    } finally {
      $hairBackBrush.Dispose()
    }

    $earBrush = [System.Drawing.SolidBrush]::new((New-Color '#EAB895'))
    try {
      $graphics.FillEllipse($earBrush, 336, 388, 48, 74)
      $graphics.FillEllipse($earBrush, 640, 388, 48, 74)
    } finally {
      $earBrush.Dispose()
    }

    $faceBrush = [System.Drawing.SolidBrush]::new((New-Color '#F3C7A4'))
    try {
      $graphics.FillEllipse($faceBrush, 362, 274, 296, 334)
    } finally {
      $faceBrush.Dispose()
    }

    $hairFrontBrush = [System.Drawing.SolidBrush]::new((New-Color '#F3F7FB'))
    try {
      $graphics.FillPie($hairFrontBrush, 336, 214, 350, 180, 180, 180)
      $graphics.FillEllipse($hairFrontBrush, 352, 232, 120, 110)
      $graphics.FillEllipse($hairFrontBrush, 548, 228, 124, 114)
      $graphics.FillEllipse($hairFrontBrush, 350, 286, 58, 146)
      $graphics.FillEllipse($hairFrontBrush, 620, 286, 48, 132)
    } finally {
      $hairFrontBrush.Dispose()
    }

    $hairLinePen = [System.Drawing.Pen]::new((New-Color '#D7E0E8'), 18)
    try {
      $graphics.DrawArc($hairLinePen, 384, 244, 250, 118, 194, 152)
    } finally {
      $hairLinePen.Dispose()
    }

    $glassesPen = [System.Drawing.Pen]::new((New-Color '#7A685B'), 16)
    try {
      $graphics.DrawEllipse($glassesPen, 406, 394, 78, 78)
      $graphics.DrawEllipse($glassesPen, 534, 394, 78, 78)
      $graphics.DrawLine($glassesPen, 484, 434, 534, 434)
    } finally {
      $glassesPen.Dispose()
    }

    $eyePen = [System.Drawing.Pen]::new((New-Color '#6E574B'), 7)
    try {
      $graphics.DrawArc($eyePen, 430, 418, 28, 18, 200, 140)
      $graphics.DrawArc($eyePen, 558, 418, 28, 18, 200, 140)
    } finally {
      $eyePen.Dispose()
    }

    $browPen = [System.Drawing.Pen]::new((New-Color '#C88F73' 180), 6)
    try {
      $graphics.DrawArc($browPen, 424, 392, 38, 18, 200, 110)
      $graphics.DrawArc($browPen, 552, 392, 38, 18, 230, 110)
    } finally {
      $browPen.Dispose()
    }

    $nosePen = [System.Drawing.Pen]::new((New-Color '#D39B7F' 188), 5)
    try {
      $graphics.DrawArc($nosePen, 494, 440, 30, 46, 290, 110)
    } finally {
      $nosePen.Dispose()
    }

    $cheekBrush = [System.Drawing.SolidBrush]::new((New-Color '#F2A596' 72))
    try {
      $graphics.FillEllipse($cheekBrush, 404, 466, 42, 26)
      $graphics.FillEllipse($cheekBrush, 576, 466, 42, 26)
    } finally {
      $cheekBrush.Dispose()
    }

    $smilePen = [System.Drawing.Pen]::new((New-Color '#A35A4F'), 8)
    try {
      $graphics.DrawArc($smilePen, 458, 486, 110, 66, 12, 156)
    } finally {
      $smilePen.Dispose()
    }

    $playShadowBrush = [System.Drawing.SolidBrush]::new((New-Color '#FF8E55' 70))
    try {
      $graphics.FillEllipse($playShadowBrush, 646, 664, 138, 138)
    } finally {
      $playShadowBrush.Dispose()
    }

    $playBrush = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
      [System.Drawing.PointF]::new(654, 654),
      [System.Drawing.PointF]::new(780, 780),
      (New-Color '#FF7E47'),
      (New-Color '#FFAF5E')
    )
    try {
      $graphics.FillEllipse($playBrush, 638, 650, 138, 138)
    } finally {
      $playBrush.Dispose()
    }

    $trianglePath = [System.Drawing.Drawing2D.GraphicsPath]::new()
    try {
      $trianglePath.AddPolygon(@(
          [System.Drawing.PointF]::new(694, 684),
          [System.Drawing.PointF]::new(694, 754),
          [System.Drawing.PointF]::new(754, 719)
        ))
      $triangleBrush = [System.Drawing.SolidBrush]::new((New-Color '#FFF8F1'))
      try {
        $graphics.FillPath($triangleBrush, $trianglePath)
      } finally {
        $triangleBrush.Dispose()
      }
    } finally {
      $trianglePath.Dispose()
    }

    $sparkBrush = [System.Drawing.SolidBrush]::new((New-Color '#FFF4D8' 184))
    try {
      $graphics.FillEllipse($sparkBrush, 714, 244, 24, 24)
      $graphics.FillEllipse($sparkBrush, 748, 284, 16, 16)
      $graphics.FillEllipse($sparkBrush, 276, 232, 20, 20)
    } finally {
      $sparkBrush.Dispose()
    }

    $graphics.ResetClip()
  } finally {
    $backgroundPath.Dispose()
  }

  Save-Png -Bitmap $bitmap -Path $assetIconPath

  $bitmap512 = Resize-Bitmap -Source $bitmap -Size 512
  $bitmap192 = Resize-Bitmap -Source $bitmap -Size 192
  $bitmap64 = Resize-Bitmap -Source $bitmap -Size 64
  $bitmap256 = Resize-Bitmap -Source $bitmap -Size 256

  try {
    Save-Png -Bitmap $bitmap512 -Path $web512Path
    Save-Png -Bitmap $bitmap192 -Path $web192Path
    Save-Png -Bitmap $bitmap512 -Path $webMask512Path
    Save-Png -Bitmap $bitmap192 -Path $webMask192Path
    Save-Png -Bitmap $bitmap64 -Path $webFaviconPath
    Save-Ico -Bitmap $bitmap256 -Path $windowsIcoPath
  } finally {
    $bitmap512.Dispose()
    $bitmap192.Dispose()
    $bitmap64.Dispose()
    $bitmap256.Dispose()
  }
} finally {
  $graphics.Dispose()
  $bitmap.Dispose()
}
