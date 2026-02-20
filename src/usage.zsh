typeset -g script_name=${funcfiletrace[1]%:*}
script_name=${${script_name:t}:r}

function usage() {
    echo
    colorful "npp – new pentest project\n" C >&1
    colorful "Author: Arshia Mashhoor\n" B >&1
    colorful "Version: $TOOL_VERSION\n\n" B >&1

    colorful "Usage:\n" R >&1
    colorful "  $script_name [--help|--version|--check-config]\n" W >&1
    colorful "  $script_name <command> [options]\n\n" W >&1

    colorful "Global options:\n" Y >&1
    colorful "  -h, --help         Show this help message\n" W >&1
    colorful "  --version          Show version\n" W >&1
    colorful "  --check-config     Validate global configuration\n\n" W >&1

    colorful "Commands:\n" G >&1
    colorful "  init               Initialize a new project (metadata only)\n" W >&1
    colorful "  new                Create directory structure for an existing project\n" W >&1
    colorful "  add                Add scope or reports to an existing project\n" W >&1
    colorful "  update             Update project/domain/subdomain status\n" W >&1
    colorful "  rm                 remove project/domain/subdomain/users\n" W >&1
    colorful "  list               List project information\n" W >&1
    colorful "  cd                 Change to project directory\n" W >&1
    colorful "  archive            Archive project\n\n" W >&1

    colorful "For command-specific options, run: $script_name <command> --help\n" C >&1
    colorful "Examples:\n" Y >&1
    colorful "  $script_name init -n myproject -t bounty\n" Y >&1
    colorful "  $script_name new -p myproject -s @scope.txt\n" Y >&1
    colorful "  $script_name add -p myproject -as -s newdomain.com\n" Y >&1
    colorful "  $script_name update -p myproject --status completed\n" Y >&1
    colorful "  $script_name list -p myproject -a\n" Y >&1
    colorful "  $script_name archive -p myproject -f 7z -s\n" Y >&1
}

# Command-specific usage functions

function usage_init() {
    echo
    colorful "Initialize a new project (metadata only).\n" C >&1
    colorful "Usage: $script_name init [options]\n\n" W >&1

    colorful "Options:\n" R >&1
    colorful "  -n, --name NAME                     Project name (required)\n" W >&1
    colorful "  -P, --path PATH                     Parent directory (default: current)\n" W >&1
    colorful "  -t, --type TYPE                     Project type: pentest|bounty|ctf|redteam\n" W >&1
    colorful "  -bp, --bounty-program PLAT:URLS     Bounty platform and URLs (e.g. hacker1:url1,url2)\n" W >&1
    colorful "  -cl, --client NAME                  Client name (for pentest/redteam)\n" W >&1
    colorful "  -pi, --pentest-info TEXT            Pentest description\n" W >&1
    colorful "  -d, --description TEXT              Project description\n" W >&1
    colorful "  --gitcreds                          Prompt for git user/email\n" W >&1
    colorful "  -r, --roe TEXT|@file                Rules of Engagement (string or file)\n" W >&1
    colorful "  --git-email EMAIL                   Git email\n" W >&1
    colorful "  --git-user USER                     Git username\n" W >&1
    colorful "  --note l|t                          Note system: local (l) or trilium (t)\n" W >&1
    colorful "  --trilium-server URL                Trilium server URL\n" W >&1
    colorful "  --trilium-api-key KEY               Trilium API key\n" W >&1
    colorful "  --trilium-parent NAME            Parent note NAME in Trilium\n" W >&1
    colorful "  -c, --config FILE                   Read all options from config file\n" W >&1
    colorful "  -h, --help                          Show this help message\n" W >&1
}

function usage_new() {
    echo
    colorful "Create directory structure for an existing project.\n" C >&1
    colorful "Usage: $script_name new [options]\n\n" W >&1

    colorful "Options:\n" R >&1
    colorful "  -p, --project NAME                  Project name (required, must already exist via init)\n" W >&1
    colorful "  -s, --scope @file|list              Domains/URLs to add as scope\n" W >&1
    colorful "  -dr, --dns-resolvd                  Run basic DNS resolution on scope\n" W >&1
    colorful "  --resolver                          Resolver to use with the dns option\n" W >&1
    colorful "  -rc, --report-count N               Number of report directories (default: 20)\n" W >&1
    colorful "  -rt, --report-template FORMAT       Report template: markdown|worddoc\n" W >&1
    colorful "  -t, --tree                          Show directory tree after creation\n" W >&1
    colorful "  -h, --help                          Show this help message\n" W >&1
}

function usage_add() {
    echo
    colorful "Add scope, reports, or notes to an existing project.\n" C >&1
    colorful "Usage: $script_name add [options]\n\n" W >&1

    colorful "Options:\n" R >&1
    colorful "  -p, --project NAME                  Project name (required)\n" W >&1
    colorful "  -as, --add-scope                    Add new scope (requires -s)\n" W >&1
    colorful "  -s, --scope @file|list              Domains/URLs to add\n" W >&1
    colorful "  -dr, --dns-resolvd                  Run DNS resolution on new scope\n" W >&1
    colorful "  --resolver                          Resolver to use with the dns option\n" W >&1
    colorful "  -ar, --add-reports N                Add N new report directories\n" W >&1
    colorful "  -an, --add-note NAME                Add a note (creates empty file)\n" W >&1
    colorful "  -au, --add-user @file|user:pass     Add user(s) to credentials/users.txt\n" W >&1
    colorful "  -h, --help                          Show this help message\n" W >&1
}


function usage_update() {
    echo
    colorful "Update project, apex domain, or subdomain status.\n" C >&1
    colorful "Usage: $script_name update [options]\n\n" W >&1

    colorful "Options:\n" R >&1
    colorful "  -p, --project NAME                      Project name (required)\n" W >&1
    colorful "  --status active|completed|archived      Update project status\n" W >&1
    colorful "  -ux, --update-apex DOMAIN               Update an apex domain\n" W >&1
    colorful "  -us, --update-subdomain SUB             Update a subdomain\n" W >&1
    colorful "  --alive true|false                      Manuall Set alive status (with -ux/-us)\n" W >&1
    colorful "  --auto-alive true|false                 auto resolve and Set alive status (with -ux/-us) and (with -dr)\n" W >&1
    colorful "  -dr, --dns-resolvd                      Run DNS resolution on choosen domain or subdomain\n" W >&1
    colorful "  --resolver                              Resolver to use with the dns option\n" W >&1
    colorful "  --workingon true|false                  Set working on status\n" W >&1
    colorful "  --inscope true|false                    Manuall Set in‑scope status (with -ux/us)\n" W >&1
    colorful "  --auto-inscope true|false               Auto recheck and Set in‑scope status (with -ux/us)\n" W >&1
    colorful "  -h, --help                              Show this help message\n" W >&1
}


function usage_rm() {
    echo
    colorful "Remove project, apex domain subdomain, user\n" C >&1
    colorful "Usage: $script_name archive [options]\n\n" W >&1

    colorful "Options:\n" R >&1
    colorful "  -p, --project NAME                  Project name (required)\n" W >&1
    colorful "  If project name without any other option we will delete the entire project\n" R >&1
    colorful "  -ax --apex                          delete apex domain from the project(with all of the subdomains)\n" W >&1
    colorful "  -su, --subdomain                    delete the subdomain\n" W >&1
    colorful "  -u, --subdomain                     delete the username and password\n" W >&1
    colorful "  -y, --yes                           overrides the are you sure question\n" W >&1
    colorful "  -h, --help                          Show this help message\n" W >&1
}

function usage_list() {
    echo
    colorful "List project information.\n" C >&1
    colorful "Usage: $script_name list [options]\n\n" W >&1

    colorful "Options:\n" R >&1
    colorful "  -P, --projects                          all project names (required or use -p for single project)\n" W >&1
    colorful "  -p, --project NAME                      Project name (required)\n" W >&1
    colorful "  -a, --all                               Show all domains and subdomains\n" W >&1
    colorful "  -ax, --apex                             List only apex domains\n" W >&1
    colorful "  -sd, --subdomains                       List all subdomains\n" W >&1
    colorful "  -cs, --current-stats                    Show project statistics\n" W >&1
    colorful "  -c, --current                           Show currently working on items\n" W >&1
    colorful "  -f, --filter alive|inscope|all          Filter output (with -a)\n" W >&1
    colorful "  -h, --help                              Show this help message\n" W >&1
}

function usage_cd() {
    echo
    colorful "Change to project directory (prints path).\n" C >&1
    colorful "Usage: $script_name cd [options]\n\n" W >&1

    colorful "Options:\n" R >&1
    colorful "  -p, --project NAME                   Project name (required)\n" W >&1
    colorful "  -h, --help                           Show this help message\n" W >&1
    colorful "       example: cd \$(npp cd -p project_name)" W >&1
}
function usage_archive() {
    echo
    colorful "Archive a project.\n" C >&1
    colorful "Usage: $script_name archive [options]\n\n" W >&1

    colorful "Options:\n" R >&1
    colorful "  -p, --project NAME                  Project name (required)\n" W >&1
    colorful "  -f, --format FORMAT                 Archive format: tar|tar.gz|tar.bz2|7z|zip|rar (default: tar.gz)\n" W >&1
    colorful "  -s, --secured                       Encrypt archive with password (supported: 7z, zip, rar)\n" W >&1
    colorful "  -h, --help                          Show this help message\n" W >&1
}
