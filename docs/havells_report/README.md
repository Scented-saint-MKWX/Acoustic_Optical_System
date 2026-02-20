# Havells India Ltd. - Management Functions Report

## Overview

This LaTeX document provides a comprehensive analysis of Havells India Ltd., a leading FMEG (Fast-Moving Electrical Goods) company in India. The report covers:

1. **Functions of Management**
   - Planning (Vision, Mission, Objectives, Strategic Planning)
   - Organising (Organogram, Departmentalisation, Structure)
   - Staffing (Recruitment, Training, Compensation)
   - Directing (Leadership, Motivation, Communication)
   - Controlling (Performance Standards, Corrective Actions)

2. **Types of Market** - Analysis of market structure and competition

3. **Financial Performance** - Comprehensive ratio analysis including:
   - Liquidity Ratios (Current Ratio)
   - Profitability Ratios (Gross Profit, Net Profit, Operating Profit)
   - Return Ratios (ROE, ROCE, ROA)
   - Solvency Ratios (Debt-Equity Ratio)
   - Market Valuation Ratios (EPS, DPS, P/E Ratio)

## How to Compile in Overleaf

1. Upload all files from this folder to your Overleaf project
2. **Important:** Add the required logo images to the `images/` folder:
   - `nitw_logo.png` - NIT Warangal full logo (for title page)
   - `nitw_logo_small.png` - NIT Warangal small logo (for header on every page)
   - `havells_logo.png` - Havells India Ltd. logo (for title page)

3. Compile using pdfLaTeX

## Image Requirements

### NIT Warangal Logo
- Download from the official NIT Warangal website
- Two sizes needed:
  - Full logo (~4cm width for title page)
  - Small logo (~1cm height for page headers)

### Havells Logo
- Download from Havells official website or media kit
- Size: ~5cm width for title page

## Customization

Edit the following sections in the LaTeX file to personalize:

```latex
% Student/Faculty Information (on title page)
\begin{tabular}{rl}
    \textbf{Submitted by:} & [Student Name] \\
    \textbf{Roll Number:} & [Roll Number] \\
    \textbf{Course:} & [Course Name] \\
    \textbf{Faculty:} & [Faculty Name] \\
\end{tabular}
```

## File Structure

```
havells_report/
├── havells_management_report.tex    # Main LaTeX document
├── README.md                        # This file
└── images/
    ├── .gitkeep                     # Placeholder
    ├── nitw_logo.png               # Add: NIT Warangal logo (full)
    ├── nitw_logo_small.png         # Add: NIT Warangal logo (small)
    └── havells_logo.png            # Add: Havells company logo
```

## Data Sources

All financial data and company information is based on:
- Havells India Ltd. Annual Reports (FY 2020-21 to FY 2022-23)
- Official company disclosures on BSE/NSE
- Company investor presentations

## Notes

- The document uses fancyhdr package for headers with NITW logo on every page
- Colors are customized to match NIT Warangal and Havells branding
- All financial ratios include formulas and calculations
- The report follows the specified format for management functions analysis

## Contact

For any issues with the template, please raise an issue in the repository.
