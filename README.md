# 🔥 NPP: NEW PENTEST PROJECT
### *Because organizing your chaos shouldn't be harder than pwning the box*

---

## 📌 WHAT THE FUCK IS THIS?

Another pentest tool? No. This is **your ADHD brain's personal assistant** that stops you from creating 47 fucking folders every time you start a new engagement.

`nnp` (new pentest project) is a **zsh script** that automagically creates that beautiful, organized directory structure you always plan to make but never actually do when the client's breathing down your neck.

---

## 🎯 FEATURES THAT DON'T SUCK

### ✅ **AUTO-SCOPE PROCESSING**
Give it domains, URLs, wildcards, or even a file - it'll:
- Extract FQDNs like a boss
- Identify apex domains automatically
- Create structured dirs for each domain/subdomain
- Handle wildcards (`*.target.com`) properly
- Validate domains (because you keep typing `gogle.com`)

### 📁 **SANE DIRECTORY STRUCTURE**
No more `~/projects/client/untitled_folder/real_folder/final_final/`
Creates:
- `reports/` (with numbered versions, you animal)
- `gathered_info/` (organized by apex domains → subdomains)
- `evidences/` (categorized because screen chaos is unprofessional)
- `tmp_exploits/` (where your 0-days live)
- Obsidian vault (for the note-taking hipsters)

### 🔄 **PROJECT UPDATES**
Already have a project? Need 10 more report folders? New scope?
`nnp -up /path/project -ar 10 -as` - **BOOM**. Done.

---

## 🚀 INSTALLATION (IT'S NOT ROCKET SCIENCE)

```bash
# 1. Clone this shit
git clone https://github.com/yourusername/nnp.git
cd nnp

# 2. Make it executable (duh)
chmod +x nnp

# 3. Move it somewhere in your PATH, you lazy bastard
sudo mv nnp /usr/local/bin/  # or ~/.local/bin/ if you're a normie
```

**OR** if you're feeling extra:

```bash
curl -sSL https://raw.githubusercontent.com/yourusername/nnp/main/nnp -o /usr/local/bin/nnp && chmod +x /usr/local/bin/nnp
```

---

## 💀 USAGE: STOP WASTING TIME

### **Basic Bitch Mode** (You have 5 minutes before the call)
```bash
nnp -n "acme_corp"  # Creates project with default structure
```

### **Pro Hacker Mode** (You actually read the scope)
```bash
nnp -n "acme_corp" -rc 30 -s @scope.txt -t
```
- `-rc 30`: Creates 30 report folders (because QA will reject it 29 times)
- `-s @scope.txt`: Processes domains from file
- `-t`: Shows tree because you like pretty things

### **Scope Input Formats** (We're flexible)
```bash
# Direct input
nnp -n test -s "example.com" "*.test.com" "https://api.target.com"

# From file
nnp -n test -s @domains.txt

# From stdin (pipe that shit)
echo -e "target.com\n*.api.target.com" | nnp -n test -s @-
```

### **Update Mode** (When you realize you fucked up)
```bash
# Add 5 more report directories (because your manager said "just one more")
nnp -up /path/to/project -ar 5

# Add new scope to existing project
nnp -dn existing_project -as -s "new.target.com" "*.api.new.com"
```

---

## 🏗️ DIRECTORY STRUCTURE (WHAT YOU GET)

```
acme_corp/
├── burp_project/          # Your Burp garbage
├── target_data/           # Client info (if they bothered to send it)
├── reports/
│   ├── all_reports/
│   │   ├── No.01/        # First attempt (will be wrong)
│   │   ├── No.02/        # Second attempt (still wrong)
│   │   └── ...           # Up to 20 (or however many you specify)
│   └── templates/        # Templates you'll never use
├── gathered_info/
│   └── apex_domains/
│       └── target-com/   # Apex domain dir
│           ├── apex_domain.txt
│           └── subdomains/
│               ├── api-target-com/
│               ├── www-target-com/
│               └── wildcard-subdomain/
│                   ├── subdomain.txt
│                   └── wildcard.txt  # Because you'll forget
├── evidences/            # Screenshots of you pwning stuff
├── tmp_exploits/         # Your 0-days and sketchy scripts
└── acme_corp_obsidian_vault/  # For the organized psychopaths
```

---

## ⚙️ OPTIONS (READ THE FINE PRINT)

| Flag | What it does | Why you care |
|------|-------------|--------------|
| `-n, --name` | Project name | Don't use spaces or slurs, dumbass |
| `-p, --path` | Where to create it | Default: current dir (wherever you ran it from) |
| `-rc, --report-count` | How many report folders | Default: 20 (optimistic, I know) |
| `-s, --scope` | Domains/URLs to process | Files need `@` prefix, e.g., `@scope.txt` |
| `-t, --tree` | Show directory tree | For that warm fuzzy feeling |
| `-up, --update-project` | Update existing project | Path to project dir |
| `-dn, --directory-name` | Update by name | Current directory assumed |
| `-ar, --add-reports` | Add more report folders | Because you ran out |
| `-as, --add-scope` | Add new domains | For when scope creeps |

---

## 🧠 PRO TIPS (FROM SOMEONE WHO'S BEEN THERE)

1. **Use scope files** - Stop typing domains manually like a caveman
2. **Wildcards matter** - `*.internal.target.com` creates proper wildcard structure
3. **Update, don't recreate** - Use `-up` when scope expands (it always does)
4. **Tree flag is your friend** - Verify the structure before you start
5. **Obsidian integration** - Actually use it for notes, you'll thank yourself later

---

## 🔮 ROADMAP (COMING SOON™)

- [ ] **GPG encryption** for sensitive reports (because opsec)
- [ ] **Project backup/restore** (for when you `rm -rf` the wrong thing)
- [ ] **Template customization** (make it your own)
- [ ] **Integration with recon tools** (automate that boring shit)
- [ ] **More color options** (because rainbow terminal is life)

---

## 🚨 WARNINGS (READ THIS, IDIOT)

1. **ZSH ONLY** - This ain't bash-compatible. Get with the times.
2. **No spaces in project names** - We're not savages.
3. **Validate your scope** - Garbage in, garbage out.
4. **Backup your shit** - I'm not responsible for your `rm -rf` accidents.

---

## 👨‍💻 AUTHOR

**Arshia Mashhoor** - The guy who got tired of manually creating directories at 3 AM.

*"I made this because I kept forgetting where I saved my fucking screenshots."*

---

## 📄 LICENSE

**WTFPL** - Do whatever the fuck you want with it. Just don't blame me when it breaks.

---

## 🎯 FINAL WORDS

Stop being a disorganized mess. Use this tool. Save your time for actual hacking.

```bash
# This is the way
nnp -n "$(whoami)_is_not_a_moron" -rc 50 -s @all_the_things.txt -t
```

**Happy hacking, you beautiful chaotic bastard.** 🏴‍☠️

---

*Found a bug? Feature request? Open an issue or fix it yourself and submit a PR. Don't be lazy.*
