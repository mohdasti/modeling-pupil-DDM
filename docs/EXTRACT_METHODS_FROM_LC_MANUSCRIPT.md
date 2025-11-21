# Guide: Extracting Methodological Details from LC Behavioral Report Manuscript

This document guides the extraction of relevant methodological information from the LC behavioral report manuscript PDF for integration into the DDM chapter report (`reports/chap3_ddm_results.qmd`).

## ⚠️ Scope: DDM-Relevant Information Only

**EXCLUDE**: Confidence scores, confidence-related analyses, and any measures beyond the scope of DDM analysis.

**INCLUDE**: Task descriptions, stimulus parameters, equipment, procedure, participant details, and design rationale relevant to DDM interpretation.

---

## 📍 Sections in QMD Where Details Should Be Added

### 1. **Participants Section** (Line ~136)
**Current**: Basic demographics and reference to manuscript  
**Add**:
- [ ] Recruitment criteria (age range, inclusion/exclusion)
- [ ] Sample size justification
- [ ] Demographics summary (if not already present)
- [ ] Reference: "For detailed recruitment and inclusion criteria, see [LC manuscript citation]"

### 2. **Tasks and Conditions Section** (Line ~138)
**Current**: Brief task names and conditions  
**Add**:
- [ ] **ADT (Auditory Detection Task)**:
  - [ ] Stimulus type (e.g., pure tones, frequency range)
  - [ ] Standard vs. target stimulus differences
  - [ ] Difficulty manipulation details (how Easy/Hard differ from Standard)
  - [ ] Presentation method (headphones, speakers, etc.)
  
- [ ] **VDT (Visual Detection Task)**:
  - [ ] Stimulus type (e.g., visual patterns, shapes, colors)
  - [ ] Standard vs. target stimulus differences
  - [ ] Difficulty manipulation details
  - [ ] Display specifications (monitor, resolution, viewing distance)
  
- [ ] **Equipment/Software**:
  - [ ] Presentation software (e.g., Psychtoolbox, E-Prime)
  - [ ] Hardware specifications
  - [ ] Response collection method (keyboard, button box, etc.)

**Reference format**: "Detailed task descriptions, stimulus parameters, and equipment specifications are provided in [LC manuscript citation]; see References."

### 3. **Trial Timeline Section** (Line ~151)
**Current**: Timeline structure  
**Add**:
- [ ] Stimulus presentation details (if not in Tasks section)
- [ ] Equipment specifications (if not in Tasks section)
- [ ] Response collection method details
- [ ] Timing precision/accuracy

**Reference format**: "Stimulus presentation parameters, equipment specifications, and response collection methods are detailed in [LC manuscript citation]; see References."

### 4. **Model Specification Section** (Line ~328)
**Current**: Model formulas and rationale  
**Add**:
- [ ] Rationale for response-signal design (if not already covered)
- [ ] Justification for difficulty/effort manipulations in DDM context
- [ ] Reference: "The response-signal task design and its implications for DDM parameter interpretation are described in [LC manuscript citation]; see References."

---

## 📋 Information Extraction Checklist

When reading the LC behavioral report manuscript PDF, extract the following **DDM-relevant** information:

### Participant Information
- [ ] Age range and mean (SD)
- [ ] Inclusion/exclusion criteria
- [ ] Sample size justification
- [ ] Demographics (if relevant to DDM interpretation)

### Task Descriptions
- [ ] **ADT**:
  - [ ] Stimulus characteristics (frequencies, durations, intensities)
  - [ ] Standard vs. target differences
  - [ ] Difficulty levels (how Easy/Hard differ)
  - [ ] Presentation method
  
- [ ] **VDT**:
  - [ ] Stimulus characteristics (visual properties, sizes, colors)
  - [ ] Standard vs. target differences
  - [ ] Difficulty levels
  - [ ] Display specifications

### Experimental Design
- [ ] Trial structure (already in QMD, but verify)
- [ ] Block structure (if relevant)
- [ ] Practice trials
- [ ] Break procedures

### Equipment & Software
- [ ] Stimulus presentation software
- [ ] Hardware (monitors, audio equipment)
- [ ] Response collection devices
- [ ] Timing specifications

### Procedure
- [ ] Instructions to participants
- [ ] Practice phase details
- [ ] Main task procedure
- [ ] Effort manipulation procedure (grip force maintenance)

### Data Collection
- [ ] RT measurement method
- [ ] Response coding
- [ ] Quality control procedures (if not already in QMD)

---

## 🚫 Information to EXCLUDE

**Do NOT extract**:
- ❌ Confidence ratings/confidence scores
- ❌ Confidence-related analyses
- ❌ Any measures not used in DDM analysis
- ❌ Results from confidence analyses
- ❌ Discussion of confidence (unless directly relevant to DDM interpretation)

---

## 📝 Template for Adding Information

Once you've extracted the relevant information, use this format to add it to the QMD:

```markdown
## Section Name

[Brief summary of information]

*[Detailed descriptions, parameters, and specifications are provided in [LC manuscript citation]; see References.]*

[Any DDM-specific interpretation or rationale]
```

---

## ✅ Next Steps

1. **Extract information** from the PDF using the checklist above
2. **Review** extracted information to ensure it's DDM-relevant
3. **Provide** the extracted information to integrate into QMD
4. **Update** References section with full citation details

---

## 📄 Current References Section Placeholder

The QMD currently has this placeholder in the References section:

```markdown
- LC Behavioral Report Manuscript (in preparation/published). *[Full citation to be added: authors, title, journal, year, DOI if available]*
```

**Please provide**:
- Authors
- Title
- Journal (if published) or status (in preparation, under review, etc.)
- Year
- DOI (if available)
- Any other citation details

---

## 🔍 Where to Find Information in PDF

Typical locations in a methods manuscript:
- **Participants**: Methods → Participants section
- **Tasks**: Methods → Materials/Tasks section
- **Procedure**: Methods → Procedure section
- **Equipment**: Methods → Apparatus/Equipment section
- **Design rationale**: Introduction or Methods → Design section

---

**Last updated**: [Current date]  
**Status**: Awaiting information extraction from PDF

