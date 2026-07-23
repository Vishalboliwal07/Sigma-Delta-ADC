
![MATLAB](https://img.shields.io/badge/MATLAB-R2025b-orange)
![Verilog](https://img.shields.io/badge/HDL-Verilog-blue)
![Vivado](https://img.shields.io/badge/Xilinx-Vivado-green)
![License](https://img.shields.io/badge/License-MIT-yellow)


# Sigma-Delta-ADC

# 20-bit Delta-Sigma ADC: Behavioral Modeling, Fixed-Point Design & RTL Implementation

A complete end-to-end implementation of a **single-bit 2nd-order Delta-Sigma Analog-to-Digital Converter (ΔΣ ADC)**, including behavioral modeling, fixed-point hardware conversion, Verilog RTL implementation, and bit-exact hardware verification.

The project follows a complete DSP hardware design flow:

```
Analog Signal
→ Delta-Sigma Modulator
→ CIC Decimation Filter
→ FIR Compensation Filter
→ 20-bit Digital Output
→ MATLAB ↔ Verilog Bit-True Verification
```

---

# Project Overview

This project implements a hardware-efficient **2nd-order single-bit Delta-Sigma ADC** capable of producing a **20-bit digital output** while achieving approximately **15-bit Effective Number of Bits (ENOB)** under hardware-realistic fixed-point conditions.

The implementation includes:

- Behavioral Delta-Sigma Modulator
- Multi-tone & Broadband Validation
- CIC Decimation Filter
- FIR Compensation Filter
- Fixed-Point Quantization
- Hardware Register Sizing
- Verilog RTL
- Bit-Exact MATLAB ↔ RTL Verification
- FFT-Based Hardware Performance Evaluation

---

# System Architecture

<p align="center">
<img src="docs/architecture/system_architecture.png" width="900">
</p>

Pipeline:

```
Analog Input
      │
      ▼
2nd Order ΔΣ Modulator
      │
1-bit Bitstream
      │
      ▼
SINC³ CIC Decimator (R = 64)
      │
      ▼
Compensation FIR (R = 4)
      │
      ▼
20-bit Digital Output
      │
      ▼
FFT / ENOB Evaluation
```

---

# Phase 1 — Behavioral Modeling

Implemented

- First-order Delta-Sigma Modulator
- Second-order Delta-Sigma Modulator
- OSR Sweep
- ENOB Characterization
- Architecture Selection

Validation

- Multi-tone testing
- Broadband testing
- Clock scaling verification
- Architecture comparison

Output

- Selected **2nd-order single-bit architecture**
- Behavioral ENOB ≈ **15.83 bits**

## ENOB Characterization

<p align="center">
<img src="docs/results/ENOB_vs_OSR.png" width="800">
</p>

The ENOB sweep demonstrates the improvement obtained through oversampling and confirms that the selected second-order architecture satisfies the design objective near **OSR = 256**.

---

## Broadband Validation

<p align="center">
<img src="docs/results/Broadband_Test.png" width="800">
</p>

Broadband verification validates the noise-shaping behavior of the ΔΣ modulator using filtered white-noise excitation.

---

# Phase 2 — Fixed-Point Hardware Design

Designed

- SINC³ CIC Filter
- FIR Compensation Filter
- Register Width Analysis
- Fixed-Point Quantization
- Q1.15 FIR Coefficients

Implemented

- 19-bit CIC datapath
- 35-bit FIR MAC
- Folded symmetric FIR
- 20-bit output rounding

Hardware optimizations

```
101 Multipliers

↓

51 Multipliers
```

Verification

- Hogenauer wraparound proof
- Quantization sweep
- Passband droop analysis
- Stopband attenuation
- Bit-true MATLAB model

## CIC Architecture

<p align="center">
<img src="docs/architecture/cic_architecture.png" width="700">
</p>

The CIC stage performs the first decimation by **64×** using a multiplier-free SINC³ architecture.

---

## FIR Compensation Architecture

<p align="center">
<img src="docs/architecture/fir_architecture.png" width="750">
</p>

A folded symmetric FIR implementation reduces the hardware complexity from **101 multipliers** to **51 multipliers** while preserving the required response.

---

## Frequency Response

<p align="center">
<img src="docs/results/Frequency_Response.png" width="800">
</p>

The compensation FIR corrects the passband droop introduced by the CIC filter while providing strong stopband attenuation.

---

# Phase 3 — Verilog RTL Implementation

Implemented modules

```
cic_integrator_stage.v

cic_comb_stage.v

cic_top.v

fir_compensation_stage.v

adc_backend_top.v
```

RTL Features

- Fully synchronous design
- Folded FIR architecture
- 19-bit CIC datapath
- 35-bit accumulator
- Hardware rounding
- Verilog coefficient memory

## RTL Pipeline

<p align="center">
<img src="docs/architecture/rtl_pipeline.png" width="850">
</p>

The RTL implementation directly follows the fixed-point architecture validated in MATLAB.

---

# Phase 4 — Hardware Verification

Verification flow

```
MATLAB

↓

Generate 1-bit Stimulus

↓

Vivado RTL Simulation

↓

RTL Output

↓

MATLAB Bit-True Comparison

↓

FFT

↓

ENOB
```

Verification Results

- MATLAB ↔ RTL comparison
- Zero steady-state discrepancy
- Bit-exact fixed-point implementation

## MATLAB ↔ RTL Verification

<p align="center">
<img src="docs/results/Verification.png" width="850">
</p>

The Verilog RTL reproduces the MATLAB bit-true model exactly, confirming functional correctness of the hardware implementation.

---

## RTL Hardware Performance

<p align="center">
<img src="docs/results/RTL_PSD.png" width="850">
</p>

FFT-based evaluation of the RTL output confirms the expected spectral characteristics and measured hardware ENOB.

---

# Results

| Metric | Value |
|---------|------:|
| Modulator | 2nd Order Single Bit |
| OSR | 256 |
| CIC | SINC³ (R=64) |
| FIR | Compensation Filter (R=4) |
| CIC Width | 19 bits |
| FIR MAC | 35 bits |
| FIR Coefficients | 16-bit Q1.15 |
| FIR Multipliers | 51 |
| Output Width | 20 bits |
| Behavioral Floating-Point ENOB | ~15.83 bits |
| MATLAB Bit-True ENOB | ~14.90 bits |
| RTL Hardware ENOB | ~14.90 bits |
| MATLAB ↔ RTL Verification | **0 LSB Steady-State Error** |

---

# Repository Structure

```text
20-bit-delta-sigma-adc/

├── docs/
├── matlab/
├── rtl/
├── verification/
├── vivado/
└── README.md
```

---

# How to Run

## Phase 1 – Behavioral Modeling

```text
main_adc_behavioral.m

↓

main_adc_sweep.m

↓

main_adc_broadband.m
```

---

## Phase 2 – Fixed-Point Design

```text
fixed_point_Verification.m

↓

design_cic_comp_fir.m

↓

filter_freq_response.m

↓

final_quantization_Exp.m
```

---

## Phase 3 – RTL Verification

```text
sin_wave.m

↓

Vivado Simulation

↓

enob_eval.m
```

---

# Tools Used

- MATLAB
- Signal Processing Toolbox
- Verilog HDL
- Xilinx Vivado

---

# Future Work

- Third-order ΔΣ Modulator
- MASH Architecture
- FPGA Implementation
- Timing Closure
- Resource Utilization Analysis
- Gate-Level Verification

---

# References

1. Richard Schreier and Gabor C. Temes, *Understanding Delta-Sigma Data Converters*. IEEE Press/Wiley-Interscience, 2005.

2. Eugene B. Hogenauer, **"An Economical Class of Digital Filters for Decimation and Interpolation,"** *IEEE Transactions on Acoustics, Speech, and Signal Processing*, vol. ASSP-29, no. 2, pp. 155–162, Apr. 1981.

3. John G. Proakis and Dimitris G. Manolakis, *Digital Signal Processing: Principles, Algorithms, and Applications*, 4th Edition, Pearson Education.

4. All About Circuits, **"Delta-Sigma ADC"**.  
   https://www.allaboutcircuits.com/textbook/digital/chpt-13/delta-sigma-adc/

5. Analog Devices, **System Applications Guide – Section 14: Oversampling and Sigma-Delta Converters**.  
   https://www.analog.com/media/en/training-seminars/design-handbooks/system-applications-guide/Section14.pdf

---

# Author

**Vishal Boliwal**

B.Tech. IC Design &  Technology

Indian Institute of Technology Gandhinagar

Class of 2028
