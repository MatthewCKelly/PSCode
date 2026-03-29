# Capstone Project A: Email Template System

## 🎯 Project Overview

Build a complete email template management system with a Windows Forms GUI that allows users to create, edit, and preview HTML email templates with variable substitution and template categories.

**Difficulty:** ⭐⭐⭐ Intermediate
**Time Required:** 8-12 hours
**Prerequisites:** Modules 1-7 (Foundations through HTML Generation)

---

## 📋 Project Requirements

### Functional Requirements

#### 1. Template Management
- Create new email templates
- Edit existing templates
- Delete templates
- Save templates to JSON files
- Load templates from JSON files
- Organize templates by category (Marketing, Support, HR, General)

#### 2. Variable Substitution
- Support variables in templates: `{{FirstName}}`, `{{Company}}`, `{{Date}}`, etc.
- Allow users to define custom variables
- Preview template with sample data
- List of common variables provided (Name, Email, Phone, Company, Date, etc.)

#### 3. HTML Editor
- Multi-line text box for HTML content
- Plain text alternative generation
- Syntax highlighting (optional enhancement)
- Insert variables via dropdown or buttons

#### 4. Preview System
- WebBrowser control for HTML preview
- Real-time preview as user types (debounced)
- Side-by-side HTML and plain text preview
- Sample data for variable substitution

#### 5. Template Library
- List of saved templates in a ListBox
- Search/filter templates by name or category
- Duplicate template feature
- Template metadata (created date, last modified, usage count)

#### 6. Export Options
- Copy HTML to clipboard
- Copy plain text to clipboard
- Save as .htm file
- Export template pack (multiple templates to ZIP)

### Technical Requirements

#### 1. Architecture
- Separate concerns: UI, Business Logic, Data Access
- Template class to represent email templates
- TemplateManager class to handle CRUD operations
- Configuration file for default variables and settings

#### 2. Data Storage
- JSON file per template in `Templates/` directory
- Central index file listing all templates
- Backup functionality (template versioning)

#### 3. GUI Requirements
- Main form minimum size: 1000x700
- Resizable with proper anchoring
- Three-panel layout:
  - Left: Template list (250px wide)
  - Center: Editor (flexible width)
  - Right: Preview (flexible width)
- Menu bar with File, Edit, View, Help
- Toolbar with common actions
- Status bar showing current template and save status

#### 4. Error Handling
- Graceful handling of missing files
- Validation before saving (non-empty name, valid HTML)
- Confirmation dialogs for destructive actions
- Error messages with specific details

---

## 🏗️ Project Structure

```
EmailTemplateSystem/
├── EmailTemplateSystem.ps1        # Main entry point
├── Classes/
│   ├── Template.ps1              # Template class definition
│   ├── TemplateManager.ps1       # CRUD operations
│   └── VariableManager.ps1       # Variable substitution logic
├── Templates/                     # Template storage
│   ├── index.json                # Template index
│   ├── Marketing/
│   ├── Support/
│   ├── HR/
│   └── General/
├── Config/
│   └── settings.json             # Default variables and settings
└── README.md                     # User guide
```

---

## 📝 Detailed Specifications

### Template Class

```powershell
class EmailTemplate {
    [string]$Id                    # GUID
    [string]$Name
    [string]$Category
    [string]$HtmlContent
    [string]$PlainTextContent
    [string[]]$Variables           # List of variables used
    [datetime]$CreatedDate
    [datetime]$LastModified
    [int]$UsageCount
    [hashtable]$Metadata           # Custom metadata

    EmailTemplate() {
        $this.Id = [guid]::NewGuid().ToString()
        $this.CreatedDate = Get-Date
        $this.LastModified = Get-Date
        $this.UsageCount = 0
        $this.Variables = @()
        $this.Metadata = @{}
    }

    [string[]] ExtractVariables() {
        # Extract {{VariableName}} from HTML content
        # Return unique list of variable names
    }

    [string] RenderWithData([hashtable]$data) {
        # Replace {{VariableName}} with values from $data
        # Return rendered HTML
    }

    [void] Save([string]$basePath) {
        # Save template to JSON file
    }

    static [EmailTemplate] Load([string]$filePath) {
        # Load template from JSON file
        # Return EmailTemplate object
    }
}
```

### TemplateManager Class

```powershell
class TemplateManager {
    [string]$BasePath
    [hashtable]$Templates          # Key: Id, Value: EmailTemplate
    [string]$IndexPath

    TemplateManager([string]$basePath) {
        $this.BasePath = $basePath
        $this.IndexPath = Join-Path $basePath "index.json"
        $this.Templates = @{}
        $this.LoadIndex()
    }

    [void] LoadIndex() {
        # Load index.json and all templates
    }

    [void] SaveIndex() {
        # Save current template list to index.json
    }

    [EmailTemplate] CreateTemplate([string]$name, [string]$category) {
        # Create new template and save
    }

    [void] SaveTemplate([EmailTemplate]$template) {
        # Save template to file
        # Update index
    }

    [void] DeleteTemplate([string]$id) {
        # Delete template file and remove from index
    }

    [EmailTemplate[]] GetTemplatesByCategory([string]$category) {
        # Return filtered list
    }

    [EmailTemplate[]] SearchTemplates([string]$searchTerm) {
        # Search by name or content
    }

    [EmailTemplate] DuplicateTemplate([string]$id) {
        # Create copy with new ID
    }
}
```

### GUI Layout

```
┌─────────────────────────────────────────────────────────────────┐
│ File  Edit  View  Help                                         │
├─────────────────────────────────────────────────────────────────┤
│ [New] [Save] [Delete] [Copy] [Variables▼]                      │
├──────────┬────────────────────────────┬─────────────────────────┤
│Templates │ Editor                     │ Preview                 │
│          │                            │                         │
│[Category▼]│ Name: [________________]  │ ┌─────────────────────┐ │
│          │                            │ │                     │ │
│├─Marketing│ Category: [Marketing ▼]   │ │  HTML Preview       │ │
││ Welcome │                            │ │  (WebBrowser)       │ │
││ Promo   │ HTML Content:              │ │                     │ │
│├─Support │ ┌────────────────────────┐ │ │                     │ │
││ Issue   │ │<html>                  │ │ │                     │ │
││ Resolved│ │<body>                  │ │ │                     │ │
│├─HR      │ │Hello {{FirstName}},    │ │ │                     │ │
││ Onboard │ │                        │ │ │                     │ │
│├─General │ │{{Content}}             │ │ │                     │ │
││ Generic │ │                        │ │ │                     │ │
│          │ │Best regards,           │ │ └─────────────────────┘ │
│          │ │{{SenderName}}          │ │                         │
│          │ └────────────────────────┘ │ Plain Text Preview:     │
│          │                            │ ┌─────────────────────┐ │
│          │ Variables: {{FirstName}},  │ │Hello John,          │ │
│          │ {{Content}}, {{SenderName}}│ │                     │ │
│          │                            │ │Content here...      │ │
│          │ [Insert Variable ▼]        │ │                     │ │
│          │ [Update Preview]           │ │Best regards, Alice  │ │
│          │                            │ └─────────────────────┘ │
├──────────┴────────────────────────────┴─────────────────────────┤
│ Status: Template "Welcome" saved | Modified: 2026-03-29 14:30  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🎨 User Stories

### Story 1: Create Marketing Email
**As a** marketing manager
**I want to** create an email template for product launches
**So that** I can quickly send consistent messages to customers

**Acceptance Criteria:**
- Can create new template in Marketing category
- Can insert variables like {{ProductName}}, {{LaunchDate}}, {{DiscountCode}}
- Can preview with sample data
- Can save and reuse template

### Story 2: Variable Substitution
**As a** support agent
**I want to** use variables in my templates
**So that** I can personalize emails without manual editing

**Acceptance Criteria:**
- Variables in format {{VariableName}}
- Preview shows variables replaced with sample data
- List of available variables is shown
- Can define custom variables

### Story 3: Template Organization
**As a** user with many templates
**I want to** organize templates by category
**So that** I can find the right template quickly

**Acceptance Criteria:**
- Templates grouped by category in list
- Can filter by category
- Can search templates by name
- Can drag-drop to reorder (enhancement)

---

## 📊 Starter Code

```powershell
# EmailTemplateSystem.ps1 - Main Script

<#
.SYNOPSIS
    Email Template Management System
.DESCRIPTION
    Create, edit, and manage HTML email templates with variable substitution
.NOTES
    Capstone Project A - Email Template System
    Course: PowerShell Development Masterclass
#>

#region Assembly Loading
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
#endregion

#region Class Definitions
# TODO: Load Template class
# TODO: Load TemplateManager class
# TODO: Load VariableManager class
#endregion

#region Configuration
$script:templatesPath = Join-Path $PSScriptRoot "Templates"
$script:configPath = Join-Path $PSScriptRoot "Config\settings.json"

# Create directories if needed
if (-not (Test-Path $script:templatesPath)) {
    New-Item -ItemType Directory -Path $script:templatesPath | Out-Null
}

# Initialize TemplateManager
$script:templateManager = [TemplateManager]::new($script:templatesPath)
$script:currentTemplate = $null
#endregion

#region GUI Components

# Main Form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Email Template Manager"
$form.Size = New-Object System.Drawing.Size(1200, 800)
$form.MinimumSize = New-Object System.Drawing.Size(1000, 700)
$form.StartPosition = "CenterScreen"

# TODO: Create menu bar
# TODO: Create toolbar
# TODO: Create left panel (template list)
# TODO: Create center panel (editor)
# TODO: Create right panel (preview)
# TODO: Create status bar

#endregion

#region Event Handlers
# TODO: New template button
# TODO: Save template button
# TODO: Delete template button
# TODO: Template selection changed
# TODO: Content changed (debounced update)
# TODO: Category filter changed
#endregion

#region Helper Functions

Function Update-TemplatePreview {
    # Get current template content
    # Get sample data
    # Perform variable substitution
    # Update WebBrowser control
}

Function Save-CurrentTemplate {
    # Validate content
    # Save via TemplateManager
    # Update status bar
}

Function Load-Template {
    param([EmailTemplate]$template)
    # Load template into editor
    # Update all UI elements
}

#endregion

# Show the form
$form.ShowDialog()
```

---

## 🧪 Testing Requirements

### Unit Tests (Manual)

1. **Template Creation**
   - Create template with all fields
   - Create template with minimal fields
   - Validate required fields

2. **Variable Substitution**
   - Single variable
   - Multiple variables
   - Nested/complex HTML
   - Missing variable (should leave placeholder)

3. **File Operations**
   - Save template
   - Load template
   - Delete template
   - Duplicate template

4. **GUI Functionality**
   - Template list updates after save
   - Category filter works
   - Search finds templates
   - Preview updates correctly

### Integration Tests

1. **End-to-End Workflow**
   - Create → Edit → Save → Close → Reload → Verify

2. **Multiple Templates**
   - Create 5 templates in different categories
   - Switch between them
   - Verify no data loss

3. **Error Scenarios**
   - Missing Templates folder
   - Corrupted JSON file
   - Disk full (simulate)

---

## 🌟 Enhancement Ideas

### Phase 1 Enhancements
- Undo/Redo functionality
- Template validation (check for broken HTML)
- Export to multiple formats (PDF, DOCX)
- Template statistics (most used, recent, etc.)

### Phase 2 Enhancements
- Rich text editor with WYSIWYG
- Image insertion and management
- Template preview with different email clients
- Attachment management

### Phase 3 Enhancements
- Email sending integration (SMTP)
- Recipient list management
- Bulk email sending with variable substitution
- Campaign tracking (open rates, click rates)
- Integration with Outlook/Exchange

---

## 📚 Learning Objectives

By completing this project, you will demonstrate mastery of:

✅ **Windows Forms GUI** - Complex multi-panel layout
✅ **Classes** - Object-oriented design in PowerShell
✅ **File I/O** - JSON serialization and deserialization
✅ **HTML Generation** - Dynamic content with variables
✅ **WebBrowser Control** - Proper initialization and usage
✅ **Event Handling** - Debounced updates, complex interactions
✅ **Error Handling** - Graceful failure and user feedback
✅ **State Management** - Tracking current template and unsaved changes
✅ **Data Structures** - Hashtables, arrays, custom objects
✅ **User Experience** - Intuitive interface design

---

## 📤 Submission Guidelines

### What to Submit

1. **Source Code**
   - All .ps1 files
   - Organized folder structure
   - Comments and documentation

2. **Sample Templates**
   - At least 5 example templates
   - Covering different categories
   - Demonstrating various features

3. **README.md**
   - Installation instructions
   - Usage guide
   - Feature list
   - Known issues

4. **Screenshots**
   - Main interface
   - Template editing
   - Preview functionality
   - Any enhancements

### Evaluation Criteria

| Category | Weight | Criteria |
|----------|--------|----------|
| **Functionality** | 40% | All required features working |
| **Code Quality** | 20% | Clean, well-organized, commented |
| **GUI Design** | 15% | Intuitive, responsive, professional |
| **Error Handling** | 10% | Graceful failures, helpful messages |
| **Documentation** | 10% | Clear README and code comments |
| **Enhancements** | 5% | Additional features beyond requirements |

---

## 💡 Tips for Success

### Start Simple
1. Get the basic GUI layout working first
2. Add template loading/saving
3. Implement variable substitution
4. Add preview functionality
5. Polish and enhance

### Use Existing Code
- Study `Add-WeektoSignature.ps1` for:
  - Form layout and resizing
  - WebBrowser control initialization
  - Event handler patterns
  - Registry → switch to JSON for templates

### Test Frequently
- Test each feature as you build it
- Don't wait until the end to test
- Keep a test template for quick validation

### Iterate on Design
- Start with basic UI
- Improve aesthetics after functionality works
- Get feedback from others

---

## 🔗 Helpful Resources

### Code Examples from Repository
- Form creation: `Add-WeektoSignature.ps1:1100-1280`
- WebBrowser control: `Add-WeektoSignature.ps1:1822-1860`
- Event handlers: `Add-WeektoSignature.ps1:2380-2440`
- HTML generation: `Add-WeektoSignature.ps1:950-1050`
- JSON handling: `Upload-ToLiquidFiles.ps1:100-145`

### Lessons to Review
- [Module 3: Configuration Management](../lessons/03-config/README.md)
- [Module 6: Windows Forms GUI](../lessons/06-gui/README.md)
- [Module 7: HTML Generation](../lessons/07-html/README.md)

---

## 🎉 Bonus Challenges

Want to go above and beyond?

1. **Template Marketplace** - Share templates with other users
2. **Version Control** - Track template changes over time
3. **Collaboration** - Multi-user editing with conflict resolution
4. **AI Integration** - Generate templates from prompts
5. **Localization** - Support multiple languages
6. **Cloud Sync** - Sync templates across machines

---

**Ready to Build? Let's Go! 🚀**

This project will take everything you've learned and combine it into a real, useful application. Take your time, test thoroughly, and don't hesitate to refer back to the course materials!
