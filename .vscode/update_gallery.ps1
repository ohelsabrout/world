$outputFile = "gallery_data.js"

Write-Host "=========================================="
Write-Host "Starting Safe Gallery Build with EXIF Fix..."
Write-Host "=========================================="

# Initialize/Clear the output file
Set-Content -Path $outputFile -Value ""

function Process-Gallery-Folder {
    param (
        [string]$arrayName,
        [string]$rawDir,
        [string]$webDir
    )
    
    # Ensure web output directory exists
    if (-not (Test-Path $webDir)) {
        New-Item -ItemType Directory -Path $webDir | Out-Null
    }

    Add-Content -Path $outputFile -Value "const $arrayName = ["
    $count = 0

    if (Test-Path $rawDir) {
        $validExts = @('.jpg', '.JPG', '.jpeg', '.JPEG', '.png', '.PNG')
        $files = Get-ChildItem -Path $rawDir -File | Where-Object { $validExts -contains $_.Extension }

        foreach ($file in $files) {
            $filename = $file.Name
            $rawPath = $file.FullName
            $webPath = "$webDir/$filename"
            $webRelativePath = "images/$(Split-Path $webDir -Leaf)/$filename"

            try {
                Add-Type -AssemblyName System.Drawing
                
                # Load safely from the RAW folder (read-only)
                $sourceImg = [System.Drawing.Image]::FromFile($rawPath)

                # Fix EXIF Rotation (Prevents portrait phone photos from turning sideways)
                try {
                    $propId = 274 # EXIF Orientation tag ID
                    if ($sourceImg.PropertyIdList -contains $propId) {
                        $orientationProp = $sourceImg.GetPropertyItem($propId)
                        $orientation = [BitConverter]::ToInt16($orientationProp.Value, 0)
                        switch ($orientation) {
                            3 { $sourceImg.RotateFlip([System.Drawing.RotateFlipType]::Rotate180FlipNone) }
                            6 { $sourceImg.RotateFlip([System.Drawing.RotateFlipType]::Rotate90FlipNone) }
                            8 { $sourceImg.RotateFlip([System.Drawing.RotateFlipType]::Rotate270FlipNone) }
                        }
                    }
                } catch {
                    # Skip if orientation tag cannot be read
                }

                $orgWidth = $sourceImg.Width
                $orgHeight = $sourceImg.Height
                $maxDim = 1400

                # Check if resizing is needed
                if ($orgWidth -gt $maxDim -or $orgHeight -gt $maxDim) {
                    if ($orgWidth -gt $orgHeight) {
                        $newWidth = $maxDim
                        $newHeight = [int]($orgHeight * ($maxDim / $orgWidth))
                    } else {
                        $newHeight = $maxDim
                        $newWidth = [int]($orgWidth * ($maxDim / $orgHeight))
                    }

                    $bmp = New-Object System.Drawing.Bitmap $newWidth, $newHeight
                    $gfx = [System.Drawing.Graphics]::FromImage($bmp)
                    $gfx.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                    $gfx.DrawImage($sourceImg, 0, 0, $newWidth, $newHeight)
                    
                    $sourceImg.Dispose()

                    # Save cleaned web copy
                    $bmp.Save($webPath, [System.Drawing.Imaging.ImageFormat]::Jpeg)
                    
                    $gfx.Dispose()
                    $bmp.Dispose()
                    Write-Host " [Processed] Resized, oriented & saved: $filename" -ForegroundColor Green
                } else {
                    # If under size limit, save the oriented image directly
                    $sourceImg.Save($webPath, [System.Drawing.Imaging.ImageFormat]::Jpeg)
                    $sourceImg.Dispose()
                    Write-Host " [Oriented] Saved as-is under limit: $filename" -ForegroundColor Cyan
                }
            } catch {
                # Fallback: If any error occurs, copy the raw file over directly
                Copy-Item -Path $rawPath -Destination $webPath -Force
                Write-Host " [Fallback] Copied raw file for $filename." -ForegroundColor Yellow
            }

            # Write the correct relative path into the JS array
            Add-Content -Path $outputFile -Value "  `"$webRelativePath`","
            $count++
        }
    } else {
        Write-Host "WARNING: Directory '$rawDir' not found!" -ForegroundColor Red
    }

    Add-Content -Path $outputFile -Value "];"
    Add-Content -Path $outputFile -Value ""
    Write-Host "Total $arrayName`: $count image(s) processed."
}

# Process both folders safely
Process-Gallery-Folder "studioImages" "images/studio-raw" "images/studio"
Process-Gallery-Folder "tattooImages" "images/tattoo-raw" "images/tattoo"

Write-Host "=========================================="
Write-Host "SUCCESS: Updated $outputFile safely!"
Write-Host "=========================================="