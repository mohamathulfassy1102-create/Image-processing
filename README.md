# FPGA-Based Image Processing using Verilog with Python Integration

This repository contains an FPGA-oriented image processing system implemented in **Verilog HDL**, integrated with **Python (PIL)** for image pre-processing and file format conversion.

**Note** : The project is not synthesizable since it has $readmemh(),$fwrite()

The project was originally provided during my internship and has been **significantly upgraded** by adding:
- Multiple image processing operations
- Modular Verilog design
- Python-based image-to-HEX conversion pipeline
- BMP image reconstruction from processed FPGA output

---

## 📌 Project Overview

The complete flow of the project is:

1. **Input Image (JPG/PNG)**  
2. **Python Script (PIL)**  
   - Resize image to `768 × 512`
   - Convert to RGB format
   - Flip vertically (BMP-compatible)
   - Convert pixel data into `.hex` format
3. **Verilog Image Reader (`image_read`)**
   - Reads HEX image data
   - Applies selected image processing operation
   - Generates pixel stream with HSYNC & VSYNC
4. **Verilog Image Writer (`image_write`)**
   - Reconstructs processed pixels
   - Writes output as a `.bmp` image file

---

## 🧠 Supported Image Processing Operations

Image operations are enabled using compile-time `define` macros:

```verilog
//`define BRIGHTNESS_OP
`define INVERSION_OP
//`define THRESHOLD_OP 
//`define BLUR_OP
//`define SHARPEN_OP
//`define EDGE_H_OP
//`define CONTRAST_OP
