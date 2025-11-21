#!/usr/bin/env python3
"""
Convert PDF figures to high-quality PNG for HTML output.
Uses pdf2image library which requires poppler.
"""
import os
import sys
from pathlib import Path

try:
    from pdf2image import convert_from_path
except ImportError:
    print("ERROR: pdf2image not installed.")
    print("Install with: pip install pdf2image")
    print("Also install poppler: brew install poppler (macOS)")
    sys.exit(1)

# Configuration
FIG_DIR = Path("output/figures")
DPI = 600  # High quality
QUALITY = 95  # PNG compression quality (0-100)

if not FIG_DIR.exists():
    print(f"ERROR: Figure directory not found: {FIG_DIR}")
    sys.exit(1)

# Find all PDF files
pdf_files = list(FIG_DIR.glob("*.pdf"))

if not pdf_files:
    print(f"No PDF files found in {FIG_DIR}")
    sys.exit(0)

print(f"Found {len(pdf_files)} PDF file(s) to convert at {DPI} DPI...\n")

success_count = 0
for pdf_file in pdf_files:
    png_file = pdf_file.with_suffix(".png")
    
    # Skip if PNG exists and is newer
    if png_file.exists() and png_file.stat().st_mtime > pdf_file.stat().st_mtime:
        print(f"⏭  Skipping {pdf_file.name} (PNG already exists and is newer)")
        success_count += 1
        continue
    
    print(f"🔄 Converting: {pdf_file.name}")
    
    try:
        # Convert PDF to image at high DPI
        images = convert_from_path(
            pdf_file,
            dpi=DPI,
            fmt='png',
            thread_count=1
        )
        
        if not images:
            print(f"    ✗ Failed: No images extracted\n")
            continue
        
        # Save first page (PDFs should be single page)
        if len(images) > 1:
            print(f"    ⚠  Warning: PDF has {len(images)} pages, using first page")
        
        # Save with high quality
        images[0].save(
            png_file,
            'PNG',
            optimize=False,  # Don't optimize (faster, better quality)
            quality=QUALITY
        )
        
        file_size = png_file.stat().st_size / 1024
        print(f"    ✓ Success ({file_size:.1f} KB)\n")
        success_count += 1
        
    except Exception as e:
        print(f"    ✗ Failed: {e}\n")

print("=" * 50)
print(f"Conversion complete: {success_count}/{len(pdf_files)} files converted successfully")

if success_count < len(pdf_files):
    print("\n⚠️  Some files failed to convert.")
    print("Make sure poppler is installed: brew install poppler")

