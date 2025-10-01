use epm
epm:install &silent-if-installed github.com/zzamboni/elvish-modules
epm:install &silent-if-installed github.com/iwoloschin/elvish-packages
epm:install &silent-if-installed github.com/muesli/elvish-libs
epm:install &silent-if-installed github.com/iandol/elvish-modules
epm:install &silent-if-installed github.com/kolbycrouch/elvish-libs
epm:install &silent-if-installed github.com/naroslife/elvish-modules

use github.com/iwoloschin/elvish-packages/python
use github.com/zzamboni/elvish-modules/alias
use github.com/zzamboni/elvish-modules/util
use github.com/zzamboni/elvish-modules/dir
use github.com/zzamboni/elvish-modules/terminal-title
use github.com/muesli/elvish-libs/git
# use github.com/iandol/elvish-modules/cmds
use github.com/naroslife/elvish-modules/log
use github.com/naroslife/elvish-modules/you-should-use

set paths = [~/.nvm/versions/node/v22.14.0/bin ~/.sdkman/candidates/gradle/current/bin ~/.local/usr/bin ~/.local/bin ~/.cargo/bin ~/.atuin/bin ~/.cargo/env ~/go/bin ~/.gem/ruby/(ruby -e 'print RUBY_VERSION')/bin $@paths]
set-env XDG_CONFIG_HOME ~/.config
set-env FZF_DEFAULT_COMMAND 'fd --type f --hidden --follow'


var asdf_data_dir = ~'/.asdf'
var asdf_dir = ~/.asdf
if (and (has-env ASDF_DATA_DIR) (!=s $E:ASDF_DATA_DIR '')) {
  set asdf_data_dir = $E:ASDF_DATA_DIR
}

if (not (has-value $paths $asdf_data_dir'/shims')) {
  set paths = [$asdf_data_dir'/shims' ~/.asdf/bin $@paths]
}

# use asdf _asdf

# set edit:completion:arg-completer[asdf] = $_asdf:arg-completer~

eval (starship init elvish | slurp)
eval (zoxide init --cmd cd elvish | slurp)
# eval (carapace _carapace|slurp)

# Set aliases for common tools
alias:new &save ll eza -l
alias:new &save la tree
alias:new &save l eza -l --icons --git -a
alias:new &save lt eza --tree --level=2 --long --icons --git
alias:new &save ltree eza --tree --level=2 --icons --git

alias:new &save cat bat
alias:new &save gcc e:gcc -fdiagnostics-color
set-env GCC_COLORS "error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01"
alias:new &save grep e:grep --color
alias:new &save egrep e:egrep --color
alias:new &save fgrep e:fgrep --color

alias:new &save fuck thefuck --alias
alias:new &save gcm git commit -m
alias:new &save tldr tldr --color=always

alias:new &save gc git commit -m
alias:new &save gca git commit -a -m
alias:new &save gp git push origin HEAD
alias:new &save gpu git pull origin
alias:new &save gst git status
alias:new &save glog git log --graph --topo-order --pretty='%w(100,0,6)%C(yellow)%h%C(bold)%C(black)%d %C(cyan)%ar %C(green)%an%n%C(bold)%C(white)%s %N' --abbrev-commit
alias:new &save gdiff git diff
alias:new &save gco git checkout
alias:new &save gb git branch
alias:new &save gba git branch -a
alias:new &save gadd git add
alias:new &save ga git add -p
alias:new &save gcoall git checkout -- .
alias:new &save gr git remote
alias:new &save gre git reset

alias:new &save dco docker compose
alias:new &save dps docker ps
alias:new &save dpa docker ps -a
alias:new &save dl docker ps -l -q
alias:new &save dx docker exec -it

alias:new &save .. cd ..
alias:new &save ... cd ../..
alias:new &save .... cd ../../..
alias:new &save ..... cd ../../../..
alias:new &save ...... cd ../../../../..


# Enable colored man pages
set-env MANPAGER "most"

# Add Docker group permissions (if needed)
use unix
fn docker-perms {
    sudo usermod -aG docker $E:USER
}

# Add Java environment variables (if needed)
set-env JAVA_HOME /usr/lib/jvm/java-17-openjdk-amd64
set paths = [ $E:JAVA_HOME/bin $@paths]

# Add Gradle and Maven to PATH (if installed via SDKMAN)
if (has-external sdk) {
    eval (sdk env | slurp)
}

set edit:insert:binding[C-a] = $edit:move-dot-sol~
set edit:insert:binding[C-e] = $edit:move-dot-eol~
set edit:insert:binding[Alt-b] = $dir:left-word-or-prev-dir~
set edit:insert:binding[Alt-f] = $dir:right-word-or-next-dir~
set edit:insert:binding[Alt-i] = $dir:history-chooser~


var detail_printKeybinds = {
log:print-stuff '@INFO:' '@Useful keybinds:'
log:print-keybind '@Ctrl - R:' '@Command history'
log:print-keybind '@Alt - ,:' '@Last command'
log:print-keybind '@Ctrl - L:' '@Directory history'
log:print-keybind '@Ctrl - N:' '@Navigation mode'
log:print-keybind '@Ctrl - a:' '@Move to the beginning of the line'
log:print-keybind '@END:' '@Move to the end of the line'
log:print-keybind '@Ctrl - u:' '@Delete from the cursor to the beginning of the line'
log:print-keybind '@Ctrl - k:' '@Delete from the cursor to the end of the line'
log:print-keybind '@Alt - b:' '@Left word or next dir'
log:print-keybind '@Alt - f:' '@Right word or next dir'
log:print-keybind '@Alt - i:' '@History chooser'
log:print-keybind '@Ctrl - Alt - Arrow:' '@Multiple cursor'
}
var detail_printTmux = {
log:print-stuff '@INFO:' '@Tmux Cheatsheet:'
log:print-keybind '@Ctrl+B D' '@Detach from the current session'
log:print-keybind '@Ctrl+B C' '@Create a new window'
log:print-keybind '@Ctrl+B N' '@Move to the next window'
log:print-keybind '@Ctrl+B %' '@Split the window vertically'
log:print-keybind '@Ctrl+B "' '@Split the window horizontally'
log:print-keybind '@Ctrl+B Arrow' '@Move to the pane in the direction of the arrow'
log:print-keybind '@Ctrl+B Space' '@Cycle through the pane layouts'
log:print-keybind '@Ctrl+B Z' '@Zoom in/out the current pane'
log:print-keybind '@Ctrl+B X' '@Close the current pane'
log:print-keybind '@Ctrl+B :' '@Enter the tmux command prompt'
log:print-keybind '@Ctrl+B ?' '@View all keybindings. Press Q to exit.'
log:print-keybind '@Ctrl+B W' '@Hierarchy. Use to kill session/windows.'
}

fn printTmux { 
  call $detail_printTmux [] [&] | column -t -s "@" -R 1,2
 } 

fn printKeybinds { 
  call $detail_printKeybinds [] [&] | column -t -s "@" -R 1,2
 }

fn help {

  each {|f| log:print-stuff '@INFO:' '@For help in the future just type help / printKeybinds / printTmux'; call $detail_printTmux [] [&]; call $detail_printKeybinds [] [&]} [detail_printTmux] | column -t -s "@" -R 1,2
}
help
