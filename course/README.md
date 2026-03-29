# PSCode Interactive Course

Welcome to the course materials for learning PowerShell through the PSCode repository!

## 🚀 Quick Start

### New to PowerShell?
1. Read [../COURSE.md](../COURSE.md) for the full course overview
2. Start with [Lesson 1.1: Script Anatomy](./lessons/01-foundations/1.1-script-anatomy.md)
3. Work through [Lab 1: Screen Lock Monitor](./labs/lab1-screen-lock-detector.md)

### Have some PowerShell experience?
1. Take the [Placement Quiz](./placement-quiz.md) to find your level
2. Skip to the recommended module
3. Browse the [Code Index](./code-index.md) for specific examples

### Want to explore?
1. Check out the [Code Index](./code-index.md)
2. Find a concept that interests you
3. Jump to the code and start experimenting

---

## 📁 Directory Structure

```
course/
├── README.md                    # You are here!
├── placement-quiz.md            # Find your starting point
├── code-index.md                # Find code examples fast
│
├── lessons/                     # Structured lessons
│   ├── 01-foundations/
│   │   ├── 1.1-script-anatomy.md
│   │   ├── 1.2-variables-scope.md
│   │   └── ...
│   ├── 02-logging/
│   ├── 03-config/
│   ├── 04-registry/
│   ├── 05-apis/
│   ├── 06-gui/
│   │   ├── 6.5-webbrowser-control.md  # Recently fixed topic!
│   │   └── ...
│   ├── 07-html/
│   ├── 08-scheduling/
│   ├── 09-serial/
│   ├── 10-sccm/
│   └── 11-advanced/
│
├── labs/                        # Hands-on projects
│   ├── lab1-screen-lock-detector.md
│   ├── lab2-implement-logging.md
│   └── ...
│
├── projects/                    # Capstone projects
│   ├── project-a-email-templates.md
│   ├── project-b-api-aggregator.md
│   └── ...
│
├── solutions/                   # Lab solutions (try first!)
│   ├── lab1-solution.ps1
│   └── ...
│
├── quizzes/                     # Knowledge checks
│   └── ...
│
└── my-work/                     # YOUR workspace
    └── (your scripts go here)
```

---

## 🎯 Learning Paths

### Path 1: Complete Beginner
**12 weeks | Start at Module 1**

Week 1-2: PowerShell Foundations
Week 2: Logging & Debugging
Week 3: Configuration Management
Week 3-4: Registry Operations
Week 4-5: REST APIs
Week 5-7: Windows Forms GUI
Week 7-8: HTML Generation
Week 8: Task Scheduling
Week 9: Serial Communication (optional)
Week 10: SCCM (optional)
Week 11: Advanced Patterns
Week 12: Capstone Project

### Path 2: GUI Developer Track
**7 weeks | Focus on UI**

Week 1: Foundations (review)
Week 2: Logging
Week 3: Configuration
Week 4: Registry
Week 5-6: Windows Forms GUI (deep dive)
Week 7: HTML Generation
Capstone: Email Template System

### Path 3: API Integration Track
**5 weeks | Focus on APIs**

Week 1: Foundations (review)
Week 2: Logging
Week 3: Configuration Management
Week 4-5: REST APIs (deep dive)
Capstone: Multi-API Aggregator

### Path 4: System Administrator Track
**6 weeks | Focus on automation**

Week 1: Foundations (review)
Week 2: Logging
Week 3: Configuration
Week 4: Registry Operations
Week 5: SCCM/ConfigMgr
Week 6: Advanced Patterns
Capstone: System Health Dashboard

---

## 📚 Available Lessons

### ✅ Completed Lessons
- [Lesson 1.1: Script Anatomy](./lessons/01-foundations/1.1-script-anatomy.md)
- [Lesson 6.5: WebBrowser Control](./lessons/06-gui/6.5-webbrowser-control.md)

### 🚧 Coming Soon
- Lesson 1.2: Variables, Types, and Scope
- Lesson 1.3: Functions and Parameters
- Lesson 1.4: Error Handling Patterns
- Lesson 2.1: Structured Logging
- And 50+ more!

---

## 🎓 Completed Labs

### ✅ Available Now
- [Lab 1: Screen Lock Monitor](./labs/lab1-screen-lock-detector.md)

### 🚧 Coming Soon
- Lab 2: Implement Logging System
- Lab 3: Config-Driven Script
- Lab 4: Registry Preferences
- Lab 5: API Client Builder
- Lab 6: Multi-Day Selector GUI
- And more!

---

## 💡 How to Learn Effectively

### 1. Active Learning
Don't just read the code - type it yourself! Muscle memory helps retention.

### 2. Break Things
Intentionally introduce errors to see what happens. Learning from mistakes is powerful.

### 3. Modify Examples
Take the examples and change them. Make them do something different.

### 4. Build Projects
Apply what you learn immediately to a real problem you're trying to solve.

### 5. Teach Others
Explain concepts to someone else (or a rubber duck!). Teaching solidifies understanding.

---

## 🛠️ Tools & Resources

### Recommended Tools
- **VS Code** with PowerShell extension (best IDE experience)
- **PowerShell ISE** (built into Windows, good for beginners)
- **Windows Terminal** (modern console experience)
- **Git** for version control

### Online Resources
- [Microsoft PowerShell Docs](https://docs.microsoft.com/powershell/)
- [PowerShell Gallery](https://www.powershellgallery.com/)
- [Reddit r/PowerShell](https://reddit.com/r/PowerShell)
- [PowerShell.org](https://powershell.org/)

### This Repository
- [../CLAUDE.md](../CLAUDE.md) - Complete codebase guide
- [../README.md](../README.md) - Project overview
- [../CODE_SIGNING.md](../CODE_SIGNING.md) - Script signing guide
- [../AUTOMATED_SIGNING.md](../AUTOMATED_SIGNING.md) - GitHub Actions signing

---

## 🤝 Contributing to the Course

Want to help improve the course? Here's how:

### Report Issues
Found a typo, broken example, or unclear explanation?
- Open an issue on GitHub
- Tag it with `course` label

### Add Content
Want to write a lesson or create a lab?
1. Fork the repository
2. Create your lesson in the appropriate directory
3. Follow the lesson template format
4. Submit a pull request

### Share Your Projects
Built something cool using what you learned?
- Add it to the `projects/community/` directory
- Include a README explaining what it does
- Show off your work!

---

## 📊 Track Your Progress

Create your own checklist file: `my-work/progress.md`

```markdown
# My PSCode Learning Journey

Started: [Date]
Goal: [What you want to achieve]

## Completed Modules
- [x] Module 1: PowerShell Foundations
- [ ] Module 2: Logging & Debugging
- [ ] Module 3: Configuration Management
...

## Projects Built
1. Screen Lock Monitor (Lab 1)
2. [Your project]
...

## Skills Acquired
- PowerShell basics
- Windows Forms GUI
- REST API integration
...

## Next Steps
- [ ] Complete Lab 2
- [ ] Build email signature tool
...
```

---

## 🏆 Certification

While this course doesn't offer formal certification, you can:

1. **Build a portfolio** of projects from the labs and capstone
2. **Contribute to open source** (this repository!)
3. **Pursue official certification:**
   - Microsoft Certified: Azure Administrator Associate
   - Microsoft 365 Certified: Modern Desktop Administrator Associate

---

## 📞 Getting Help

### Stuck on a Lesson?
1. Re-read the code examples carefully
2. Check the [Code Index](./code-index.md) for similar patterns
3. Read the [CLAUDE.md](../CLAUDE.md) guide
4. Search the repository for similar implementations

### Found a Bug in Course Materials?
1. Check if it's already reported in GitHub Issues
2. If not, create a new issue with:
   - Which lesson/lab
   - What the problem is
   - What you expected
   - Screenshots if applicable

### Want to Discuss Concepts?
- Open a discussion on GitHub
- Tag it with `question` or `discussion`
- Share your learning experience!

---

## 🎉 Success Stories

*This section will be updated with student projects and achievements!*

Share your success story:
1. Complete a major project
2. Write a brief summary (150-300 words)
3. Include screenshots or code snippets
4. Submit a PR to add it here!

---

## 📅 Course Roadmap

### Phase 1 (Current)
- ✅ Course structure created
- ✅ Placement quiz
- ✅ Code index
- ✅ Sample lessons (2 complete)
- ✅ Sample lab (1 complete)
- 🚧 Remaining lessons (in progress)
- 🚧 Remaining labs (in progress)

### Phase 2 (Upcoming)
- 📋 Quiz modules
- 📋 Solutions for all labs
- 📋 Capstone project templates
- 📋 Video walkthroughs
- 📋 Interactive exercises

### Phase 3 (Future)
- 📋 Community project gallery
- 📋 Advanced modules
- 📋 Cloud integration (Azure/AWS)
- 📋 PowerShell Core (cross-platform)

---

## 📖 About This Course

This course was created to transform the PSCode repository into a comprehensive learning resource. Rather than just documenting the code, it provides structured lessons, hands-on labs, and progressive learning paths that use real production code as examples.

**Philosophy:**
- Learn by doing, not just reading
- Real code, real patterns, real problems
- Progressive complexity
- Multiple learning tracks for different goals

**Created:** March 2026
**Version:** 1.0
**Based on:** PSCode Repository (~10,000 lines of production PowerShell)

---

## 🚀 Get Started Now!

Ready to begin your PowerShell journey?

1. **Complete beginner?** → [Lesson 1.1: Script Anatomy](./lessons/01-foundations/1.1-script-anatomy.md)
2. **Have some experience?** → [Take the Placement Quiz](./placement-quiz.md)
3. **Just exploring?** → [Browse the Code Index](./code-index.md)

**Happy Learning! 📚✨**
