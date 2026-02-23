# 🔥 NPP: NEW PENTEST PROJECT
### *Stop wasting time on folder structures, start pwning boxes*

---

## 📌 WHAT THE F IS THIS?

`npp` (new pentest project) is your **personal project manager** that automates the boring shit you always do at the start of an engagement. No more manually creating 47 folders, no more losing notes in random directories, no more "where did I save that screenshot?"

It handles:
- **Project metadata** (client, type, rules of engagement, bounty platforms, etc.)
- **Directory structure** (organized by apex domains, subdomains, reports, evidences)
- **Scope processing** (domains, URLs, wildcards – from file or stdin)
- **DNS resolution** (basic A record checks with retries, custom resolvers)
- **JSON databases** (global project index + per‑project detailed data)
- **Updates** (add scope, reports, notes, users)
- **Status tracking** (project state, domain/subdomain alive/working/inscope)
- **Listing** (filtered by alive/inscope, show stats, current work)
- **Archiving** (tar, tar.gz, tar.bz2, 7z, zip, rar – with password support)
- **Removal** (project, apex, subdomain, user – with confirmation)
- **Trilium integration** (create notes in your favourite note‑taking app)
- **Config file support** (for those who hate typing)

---

## 🚀 INSTALLATION (IT'S NOT ROCKET SCIENCE)

```bash
# Clone the repo
git clone https://github.com/a-mashhoor/npp.git npp && cd npp/src

# Make it executable
chmod +x npp.zsh

# Move it to your PATH (pick one)
sudo ln -sf  `pwd`/npp.zsh /usr/local/bin/npp           # system-wide
ln -sf  `pwd`/npp.zsh  $HOME/.local/bin/npp             # user only (add to PATH if needed)
```


---

## 💀 USAGE: STOP WASTING TIME

### **Initialize a new project**
```bash
npp init -n myproject -t bounty -bp "hacker1:https://hackerone.com/foo" -d "Critical API testing" --note t --trilium-server http://localhost:8080 --trilium-api-key your-key
```
This only creates a **global entry** (no directories yet). The real structure comes later with `new`.

### **Create directories for an existing project**
```bash
npp new -p myproject -s @scope.txt -rc 30 -t
```
- `-p` project name (must already exist)
- `-s` scope (file with `@` prefix, or space‑separated list)
- `-rc` number of report folders (default 20)
- `-t` show directory tree

### **Add more stuff to an existing project**
```bash
npp add -p myproject -as -s newdomain.com -dr --resolver 8.8.8.8
npp add -p myproject -ar 5
npp add -p myproject -an "quick_notes"
npp add -p myproject -au admin:password123
```

### **Update status**
```bash
npp update -p myproject --status completed
npp update -p myproject -ux example.com --alive false --workingon true
npp update -p myproject -us sub.example.com --auto-alive -dr
```

### **List stuff**
```bash
npp list -P                               # all project names
npp list -p myproject -a                  # all domains & subdomains
npp list -p myproject -ax                 # only apex domains
npp list -p myproject -sd                 # only subdomains
npp list -p myproject -cs                 # statistics
npp list -p myproject -c                  # currently working on
npp list -p myproject -a -f alive         # only alive entries
```

### **Change to project directory (prints path)**
```bash
cd $(npp cd -p myproject)
```

### **Archive a project**
```bash
npp archive -p myproject -f 7z -s         # password‑protected 7z
npp archive -p myproject -f tar.bz2       # good ol' tarball
```

### **Remove stuff (with confirmation)**
```bash
npp rm -p myproject                        # delete entire project
npp rm -p myproject -ax example.com        # remove apex + all subs
npp rm -p myproject -su sub.example.com    # remove single subdomain
npp rm -p myproject -u admin:password123   # remove user line
npp rm -p myproject -y                     # skip confirmation
```

---

## 📁 DIRECTORY STRUCTURE (WHAT YOU GET)

```
myproject/
├── burp_project/               # Burp session files
├── target_data/
│   ├── scope/                   # original scope files
│   ├── credentials/             # users.txt (passwords optional)
│   ├── api_documents/           # API docs from client
│   └── general_data/            # general description, etc.
├── reports/
│   ├── templates/                # report templates (you'll never use them)
│   └── all_reports/
│       ├── No.01/                 # first attempt
│       │   ├── evidences/
│       │   ├── edited_media/
│       │   └── ...
│       ├── No.02/                 # second attempt
│       └── ...
├── my_evaluation/                 # your personal notes
├── gathered_info/
│   ├── network/                    # ASNs, CIDRs, CDN, whois
│   ├── screen_shots/                # pictures of your pwns
│   ├── crawlers_results/             # katana, etc.
│   ├── dns_results/                   # raw DNS output
│   ├── fuzzing_results/                # ffuf, feroxbuster
│   ├── RBAC/                           # role‑based access control stuff
│   └── apex_domains/
│       └── example-com/                 # apex domain dir
│           ├── apex_domain.txt
│           └── subdomains/
│               ├── www-example-com/
│               │   ├── subdomain.txt
│               │   ├── tech_stack/       # technologies.json
│               │   └── URLs/              # wayback/gathered URLs
│               └── api-example-com/
├── tmp_exploits/                    # your 0‑days (keep them safe)
│   ├── custom_src/
│   ├── payloads/
│   ├── bin/
│   └── files2u/
├── myproject_local_notes/            # local markdown notes (if --note l)
│   ├── observations.md
│   └── tmp.md
└── .local.data.json                  # per‑project JSON (don't touch if you do you will f up the tool)
```

---

## ⚙️ OPTIONS (READ THE FINE PRINT)

### Global
| Option | Description |
|--------|-------------|
| `-h, --help` | Show this help |
| `--version` | Show version |
| `--check-config FILE` | Validate a config file |

### Commands
| Command | Description |
|---------|-------------|
| `init`  | Initialize project (metadata only) |
| `new`   | Create directory structure |
| `add`   | Add scope/reports/notes/users |
| `update`| Update status (project/apex/subdomain) |
| `rm`    | Remove project/apex/subdomain/user |
| `list`  | List projects/domains/subdomains |
| `cd`    | Print project path |
| `archive` | Archive project |

Run `npp <command> --help` for command‑specific options.

---

## 🧠 PRO TIPS

- **Use config files** for repetitive options. Example `~/.npprc`:
  ```
  type=bounty
  note=t
  trilium-server=http://localhost:8080
  trilium-api-key=your-key
  trilium-parent=team-projects
  ```
  Then: `npp init -n myproject -c ~/.npprc`

- **DNS resolution** with `-dr` is reliable (5 retries). Use `--resolver` to specify a custom DNS server.
- **Auto‑alive** in `update` re‑resolves the domain and updates `is_alive` and IPs.
- **Wildcard domains** (`*.example.com`) are handled properly: directory `wildcard-subdomain`, files indicate wildcard.
- **Trilium** integration creates a book note for the project and child notes `notes_tmp` and `observations`. Make sure the parent note exists.
- **Global JSON** lives in `~/.local/share/npp/global.json`. Back it up if you care.

---

## 🔮 ROADMAP (COMING SOON™)

- [ ] **GPG encryption** for sensitive reports
- [ ] **Backup/restore** projects (export/import)
- [ ] **More recon integrations** (subfinder, httpx, nuclei)
- [ ] **Template system** for custom directory layouts
- [ ] **Web UI** (maybe, if I get bored)

---

## 🚨 WARNINGS (READ THIS, ID\*\*T)

1. **ZSH ONLY** – This script uses zsh‑isms. Don't try with bash.
2. **No spaces in project names** – `npp init -n "my project"` will break. Use underscores or hyphens.
3. **Always validate your scope** – `process_scope` does its best, but garbage in = garbage out.
4. **Backup your global JSON** – It's the brain of the tool. Lose it, lose your project index.
5. **`rm` is destructive** – Confirmation is there for a reason. Don't `-y` unless you're sure.

---

## 👨‍💻 AUTHOR

**Arshia Mashhoor** – *"I made this because I kept losing my screenshots."*

GitHub: [@a-mashhoor](https://github.com/a-mashhoor)

---

## 📄 LICENSE

**WTFPL** – Do whatever the f..k you want with it. No warranties, no liabilities, just code.

---

## 🎯 FINAL WORDS

Stop being a disorganized mess. Use this tool. Save your time for actual hacking.

```bash
# This is the way
npp init -n "$(whoami)_is_organized" -t bounty -bp "hacker1:https://hackerone.com/foo"
npp new -p "$(whoami)_is_organized" -s @scope.txt -rc 30 -t
```

**Happy hacking, you beautiful chaotic bastard.** 🏴‍☠️

---

*Found a bug? Open an issue. Want a feature? Submit a PR. Don't just complain.*
