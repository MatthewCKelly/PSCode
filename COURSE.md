# PowerShell Development Masterclass
## Learn Real-World PowerShell Through the PSCode Repository

**Course Duration:** 8-12 weeks
**Difficulty:** Beginner to Advanced
**Prerequisites:** Basic command-line experience
**What You'll Build:** Outlook signature manager, RSS processors, serial communication tools, and more

---

## 🎯 Course Overview

This is not a typical tutorial. You'll learn PowerShell by exploring, understanding, and extending a real production codebase. Every lesson uses actual code from this repository, giving you experience with real-world patterns, challenges, and solutions.

### What Makes This Course Different

✅ **Real Code, Real Patterns** - No toy examples; learn from 10,000+ lines of production PowerShell
✅ **Progressive Complexity** - Start simple, build to advanced GUI and API work
✅ **Hands-On Projects** - Modify and extend actual tools people use
✅ **Multiple Domains** - GUI development, API integration, system automation, serial I/O
✅ **Best Practices Built-In** - Logging, error handling, configuration management from day one

---

## 📚 Course Modules

### Module 1: PowerShell Foundations (Week 1-2)
**Start here if you're new to PowerShell**

- [Lesson 1.1: Script Anatomy & Execution](./course/lessons/01-foundations/1.1-script-anatomy.md)
- [Lesson 1.2: Variables, Types, and Scope](./course/lessons/01-foundations/1.2-variables-scope.md)
- [Lesson 1.3: Functions and Parameters](./course/lessons/01-foundations/1.3-functions-parameters.md)
- [Lesson 1.4: Error Handling Patterns](./course/lessons/01-foundations/1.4-error-handling.md)
- [Lab 1: Build Your First Utility](./course/labs/lab1-screen-lock-detector.md)

**Learning Path:** `isScreenLocked` → Simple utilities

---

### Module 2: Logging & Debugging (Week 2)
**Master the Write-Detail function and debugging techniques**

- [Lesson 2.1: Structured Logging](./course/lessons/02-logging/2.1-structured-logging.md)
- [Lesson 2.2: Log Levels and When to Use Them](./course/lessons/02-logging/2.2-log-levels.md)
- [Lesson 2.3: CM Log Format (CMTrace)](./course/lessons/02-logging/2.3-cm-log-format.md)
- [Lesson 2.4: Debugging Techniques](./course/lessons/02-logging/2.4-debugging.md)
- [Lab 2: Add Logging to Your Script](./course/labs/lab2-implement-logging.md)

**Learning Path:** `Write-Detail` function → `Export-WindowsUpdateEventsToLog.ps1`

---

### Module 3: Configuration Management (Week 3)
**Learn to handle JSON configs and protect secrets**

- [Lesson 3.1: JSON Configuration Files](./course/lessons/03-config/3.1-json-configs.md)
- [Lesson 3.2: Validation and Error Messages](./course/lessons/03-config/3.2-validation.md)
- [Lesson 3.3: Template Pattern](./course/lessons/03-config/3.3-templates.md)
- [Lesson 3.4: Git Security (.gitignore)](./course/lessons/03-config/3.4-git-security.md)
- [Lab 3: Create a Configurable Script](./course/labs/lab3-config-driven-script.md)

**Learning Path:** Config templates → `Upload-ToLiquidFiles.ps1` → `RssDownloadandStart-v2.ps1`

---

### Module 4: Windows Registry & Persistence (Week 3-4)
**Store and retrieve user preferences**

- [Lesson 4.1: Reading Registry Values](./course/lessons/04-registry/4.1-reading-registry.md)
- [Lesson 4.2: Writing Registry Values](./course/lessons/04-registry/4.2-writing-registry.md)
- [Lesson 4.3: Registry Data Types](./course/lessons/04-registry/4.3-data-types.md)
- [Lesson 4.4: User vs Machine Hives](./course/lessons/04-registry/4.4-hives.md)
- [Lab 4: Build a Preferences System](./course/labs/lab4-registry-preferences.md)

**Learning Path:** `Test-RegistryValueType.ps1` → Proxy settings scripts → Signature manager registry

---

### Module 5: REST API Integration (Week 4-5)
**Master API authentication and data exchange**

- [Lesson 5.1: HTTP Basics in PowerShell](./course/lessons/05-apis/5.1-http-basics.md)
- [Lesson 5.2: JSON Serialization](./course/lessons/05-apis/5.2-json.md)
- [Lesson 5.3: Authentication (Basic, Token, OAuth)](./course/lessons/05-apis/5.3-authentication.md)
- [Lesson 5.4: Multipart File Uploads](./course/lessons/05-apis/5.4-multipart-uploads.md)
- [Lesson 5.5: Error Handling & Retries](./course/lessons/05-apis/5.5-error-handling.md)
- [Lab 5: Build an API Client](./course/labs/lab5-api-client.md)

**Learning Path:** `Test-LiquidFilesAccess.ps1` → `Upload-ToLiquidFiles.ps1` → Plex API in RSS processor

---

### Module 6: Windows Forms GUI Development (Week 5-7)
**Create professional desktop applications**

- [Lesson 6.1: Your First Form](./course/lessons/06-gui/6.1-first-form.md)
- [Lesson 6.2: Layout and Controls](./course/lessons/06-gui/6.2-layout-controls.md)
- [Lesson 6.3: Events and Handlers](./course/lessons/06-gui/6.3-events.md)
- [Lesson 6.4: Dynamic Control Creation](./course/lessons/06-gui/6.4-dynamic-controls.md)
- [Lesson 6.5: WebBrowser Control](./course/lessons/06-gui/6.5-webbrowser.md)
- [Lesson 6.6: Resizing and Anchoring](./course/lessons/06-gui/6.6-resizing.md)
- [Lesson 6.7: Form State Management](./course/lessons/06-gui/6.7-state-management.md)
- [Lab 6: Build a Multi-Day Selector GUI](./course/labs/lab6-day-selector-gui.md)

**Learning Path:** Simple forms → COM port selector → **Full signature manager GUI**

---

### Module 7: HTML Generation & Email (Week 7-8)
**Generate and manipulate HTML programmatically**

- [Lesson 7.1: HTML String Building](./course/lessons/07-html/7.1-html-basics.md)
- [Lesson 7.2: Table Generation](./course/lessons/07-html/7.2-tables.md)
- [Lesson 7.3: Regex for HTML Manipulation](./course/lessons/07-html/7.3-regex-html.md)
- [Lesson 7.4: MSO Tag Cleanup](./course/lessons/07-html/7.4-mso-cleanup.md)
- [Lesson 7.5: Plain Text from HTML](./course/lessons/07-html/7.5-plain-text.md)
- [Lab 7: HTML Signature Generator](./course/labs/lab7-html-generator.md)

**Learning Path:** Simple HTML → Table generation → Signature manager HTML/text

---

### Module 8: Task Scheduling & Automation (Week 8)
**Automate scripts without admin rights**

- [Lesson 8.1: Scheduled Tasks Overview](./course/lessons/08-scheduling/8.1-overview.md)
- [Lesson 8.2: XML-Based Task Creation](./course/lessons/08-scheduling/8.2-xml-tasks.md)
- [Lesson 8.3: Triggers (Logon, Unlock, Time)](./course/lessons/08-scheduling/8.3-triggers.md)
- [Lesson 8.4: Non-Admin Task Registration](./course/lessons/08-scheduling/8.4-non-admin.md)
- [Lesson 8.5: Interval Limiting](./course/lessons/08-scheduling/8.5-intervals.md)
- [Lab 8: Auto-Run Your Script](./course/labs/lab8-scheduled-task.md)

**Learning Path:** Manual runs → Scheduled task creation → Auto-run with throttling

---

### Module 9: Serial Communication (Week 9)
**Interact with hardware devices**

- [Lesson 9.1: Serial Port Basics](./course/lessons/09-serial/9.1-basics.md)
- [Lesson 9.2: Reading Data Streams](./course/lessons/09-serial/9.2-reading-streams.md)
- [Lesson 9.3: NMEA Protocol Parsing](./course/lessons/09-serial/9.3-nmea.md)
- [Lesson 9.4: CSV Logging](./course/lessons/09-serial/9.4-csv-logging.md)
- [Lesson 9.5: Terminal Emulation](./course/lessons/09-serial/9.5-terminal.md)
- [Lab 9: GPS Data Logger](./course/labs/lab9-gps-logger.md)

**Learning Path:** `Serial/CheckComm.ps1` → GPS terminal → Custom serial tools

---

### Module 10: SCCM/ConfigMgr Automation (Week 10)
**Enterprise configuration management**

- [Lesson 10.1: ConfigMgr Module](./course/lessons/10-sccm/10.1-module.md)
- [Lesson 10.2: WMI Queries](./course/lessons/10-sccm/10.2-wmi.md)
- [Lesson 10.3: Collection Management](./course/lessons/10-sccm/10.3-collections.md)
- [Lesson 10.4: Query Rules](./course/lessons/10-sccm/10.4-query-rules.md)
- [Lesson 10.5: Event Log Integration](./course/lessons/10-sccm/10.5-event-logs.md)
- [Lab 10: Collection Creator](./course/labs/lab10-collection-creator.md)

**Learning Path:** `Create-APP-AD-CollectionsAndRules.ps1` → `Export-WindowsUpdateEventsToLog.ps1`

---

### Module 11: Advanced Patterns (Week 11)
**Master techniques, scriptblocks, and classes**

- [Lesson 11.1: Scriptblocks as Variables](./course/lessons/11-advanced/11.1-scriptblocks.md)
- [Lesson 11.2: Classes in PowerShell](./course/lessons/11-advanced/11.2-classes.md)
- [Lesson 11.3: Regex Mastery](./course/lessons/11-advanced/11.3-regex.md)
- [Lesson 11.4: Performance Optimization](./course/lessons/11-advanced/11.4-performance.md)
- [Lesson 11.5: Code Signing](./course/lessons/11-advanced/11.5-code-signing.md)
- [Lab 11: Refactor for Performance](./course/labs/lab11-optimization.md)

**Learning Path:** Patterns across all scripts → Best practices consolidation

---

### Module 12: Capstone Projects (Week 12)
**Build something new from scratch**

Choose one or build multiple:

- [Project A: Email Template System](./course/projects/project-a-email-templates.md)
- [Project B: Multi-API Aggregator](./course/projects/project-b-api-aggregator.md)
- [Project C: System Health Dashboard](./course/projects/project-c-health-dashboard.md)
- [Project D: Hardware Monitor GUI](./course/projects/project-d-hardware-monitor.md)

---

## 🎓 Learning Tracks

Not everyone needs to learn everything. Choose your track:

### Track 1: System Administrator
**Focus on automation and enterprise tools**
- Modules: 1, 2, 3, 4, 10, 11
- Time: 6 weeks
- Capstone: Project C (System Health Dashboard)

### Track 2: GUI Developer
**Focus on Windows Forms applications**
- Modules: 1, 2, 3, 4, 6, 7, 11
- Time: 7 weeks
- Capstone: Project A (Email Template System)

### Track 3: API Integration Specialist
**Focus on web services and data exchange**
- Modules: 1, 2, 3, 5, 11
- Time: 5 weeks
- Capstone: Project B (Multi-API Aggregator)

### Track 4: Full Stack (Complete Course)
**Learn everything**
- Modules: 1-12
- Time: 12 weeks
- Capstone: Your choice + custom project

---

## 🛠️ Course Setup

### Prerequisites

**Required:**
- Windows 10/11 or Windows Server 2016+
- PowerShell 5.1 or higher
- A text editor (VS Code recommended)
- Git for version control

**Optional (for specific modules):**
- Outlook (for Module 7)
- Serial device or GPS (for Module 9)
- SCCM access (for Module 10)

### Setting Up Your Environment

```powershell
# 1. Clone this repository
git clone https://github.com/MatthewCKelly/PSCode.git
cd PSCode

# 2. Create your learning branch
git checkout -b learning/[your-name]

# 3. Set execution policy (if needed)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# 4. Install VS Code (recommended)
# Download from: https://code.visualstudio.com/

# 5. Install PowerShell extension for VS Code
code --install-extension ms-vscode.PowerShell

# 6. Create your workspace
mkdir course/my-work
cd course/my-work
```

### Repository Structure for Learning

```
PSCode/
├── course/                          # 👈 Course materials (new)
│   ├── lessons/                     # Individual lesson files
│   │   ├── 01-foundations/
│   │   ├── 02-logging/
│   │   ├── 03-config/
│   │   └── ...
│   ├── labs/                        # Hands-on exercises
│   ├── projects/                    # Capstone projects
│   ├── solutions/                   # Lab solutions (try first!)
│   ├── quizzes/                     # Knowledge checks
│   └── my-work/                     # Your workspace
│
├── [Existing scripts...]            # Production code to learn from
├── Add-WeektoSignature.ps1
├── RssDownloadandStart-v2.ps1
└── ...
```

---

## 📖 How to Use This Course

### The Learning Loop

For each lesson:

1. **Read** the lesson markdown file
2. **Examine** the referenced production code
3. **Experiment** in the interactive console
4. **Complete** the hands-on exercises
5. **Test** your understanding with quizzes
6. **Build** the lab project
7. **Compare** with provided solutions
8. **Extend** (optional challenges)

### Lesson Format

Each lesson follows this structure:

```markdown
# Lesson X.Y: Topic Name

## 🎯 Learning Objectives
What you'll be able to do after this lesson

## 📚 Concepts
Theory and explanation

## 🔍 Code Exploration
Specific code from this repo to examine

## 💻 Interactive Exercise
Try it yourself in the console

## ✍️ Practice
Short coding challenges

## 🔗 Related Code
Where else this pattern appears

## ✅ Knowledge Check
Quiz questions

## 🚀 Next Steps
What's coming next
```

### Lab Format

Each lab is a guided project:

```markdown
# Lab X: Project Name

## Objective
What you'll build

## Requirements
Functional specifications

## Starter Code
Template to begin with

## Step-by-Step Guide
Incremental instructions

## Testing
How to verify it works

## Extensions
Optional challenges

## Solution
Reference implementation
```

---

## 📊 Progress Tracking

### Completion Checklist

Track your progress through the course:

- [ ] Module 1: PowerShell Foundations
  - [ ] Lesson 1.1: Script Anatomy
  - [ ] Lesson 1.2: Variables & Scope
  - [ ] Lesson 1.3: Functions
  - [ ] Lesson 1.4: Error Handling
  - [ ] Lab 1: Screen Lock Detector

- [ ] Module 2: Logging & Debugging
  - [ ] Lesson 2.1: Structured Logging
  - [ ] Lesson 2.2: Log Levels
  - [ ] Lesson 2.3: CM Log Format
  - [ ] Lesson 2.4: Debugging
  - [ ] Lab 2: Implement Logging

[Continue for all modules...]

### Skill Badges

Earn badges as you progress:

🏅 **PowerShell Initiate** - Complete Module 1
🏅 **Logger** - Complete Module 2
🏅 **Config Master** - Complete Module 3
🏅 **Registry Wrangler** - Complete Module 4
🏅 **API Ninja** - Complete Module 5
🏅 **GUI Architect** - Complete Module 6
🏅 **HTML Smith** - Complete Module 7
🏅 **Automation Wizard** - Complete Module 8
🏅 **Serial Expert** - Complete Module 9
🏅 **Enterprise Automator** - Complete Module 10
🏅 **Pattern Master** - Complete Module 11
🏅 **PowerShell Guru** - Complete all modules + capstone

---

## 💡 Study Tips

### For Beginners

1. **Don't skip modules** - They build on each other
2. **Type the code yourself** - Don't copy/paste
3. **Break things intentionally** - Learn by debugging
4. **Ask "why"** - Understand the reasoning behind patterns
5. **Take breaks** - Complex topics need time to sink in

### For Intermediate Learners

1. **Jump to interesting modules** - But review prerequisites
2. **Compare patterns** - See how concepts recur across scripts
3. **Extend the exercises** - Add features beyond requirements
4. **Read all the code** - Even scripts not in your track
5. **Contribute improvements** - Submit PRs to the repo

### For Advanced Learners

1. **Focus on patterns** - Extract reusable techniques
2. **Challenge the design** - Could it be done better?
3. **Teach someone else** - Best way to solidify knowledge
4. **Build your library** - Create reusable modules
5. **Contribute lessons** - Help improve the course

---

## 🤝 Community & Support

### Getting Help

- **Inline Comments**: Every production script has extensive comments
- **CLAUDE.md**: AI assistant guidelines (great reference)
- **CODE_SIGNING.md**: Detailed guide for script signing
- **GitHub Issues**: Ask questions, report problems
- **Discussions**: Share projects, get feedback

### Contributing

Found a bug in a lesson? Have an idea for a project? Want to add content?

```bash
# Create a course improvement branch
git checkout -b course/improvement-description

# Make your changes
# Add lessons, fix typos, improve exercises

# Commit and push
git add .
git commit -m "Improve lesson X.Y with better examples"
git push origin course/improvement-description

# Create a pull request
```

---

## 📜 License & Usage

This course is built on the PSCode repository and follows the same license.

**You are free to:**
- Use this course for learning
- Share it with others
- Adapt it for teaching
- Build upon the examples

**Please:**
- Give credit to the original repo
- Share improvements back to the community
- Don't sell the course materials
- Respect the code's original license

---

## 🎬 Ready to Start?

Choose your path:

1. **Complete Beginner?** → Start with [Lesson 1.1: Script Anatomy](./course/lessons/01-foundations/1.1-script-anatomy.md)
2. **Some PowerShell experience?** → Take the [Placement Quiz](./course/placement-quiz.md)
3. **Want to skip to GUI?** → Review prerequisites, then jump to [Module 6](./course/lessons/06-gui/README.md)
4. **Just want to explore?** → Browse the [Code Index](./course/code-index.md)

---

## 📈 Course Roadmap

### Version 1.0 (Current)
- Core 12 modules
- 60+ lessons
- 12 hands-on labs
- 4 capstone projects

### Planned Additions
- Video walkthroughs
- Live coding sessions
- Community project gallery
- Advanced modules (DSC, Desired State Configuration)
- Cloud integration (Azure, AWS)
- Additional language tracks (Python comparison)

---

**Last Updated:** 2026-03-29
**Course Version:** 1.0
**Based on:** PSCode Repository

**Happy Learning! 🚀**
