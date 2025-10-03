# You-Should-Use for Elvish Shell
# Converted from zsh-you-should-use plugin
# https://github.com/MichaelAquilina/zsh-you-should-use

use str
use github.com/zzamboni/elvish-modules/alias

# Version info
var YSU_VERSION = '1.0.0-elvish'

# Message buffer to store reminder messages
var message_buffer = ""

# Flush the message buffer to output
fn flush-ysu-buffer {
  if (not-eq $message_buffer "") {
    echo $message_buffer
    set message_buffer = ""
  }
}

# Write to message buffer with position handling
fn write-ysu-buffer {|message|
  set message_buffer = $message_buffer$message
  
  # Determine message position (before or after command execution)
  var position = $E:YSU_MESSAGE_POSITION
  if (eq $position "") {
    set position = "before"
  }
  
  if (eq $position "before") {
    flush-ysu-buffer
  } elif (not-eq $position "after") {
    echo (styled "Unknown value for YSU_MESSAGE_POSITION '"$position"'. Expected 'before' or 'after'" red bold)
    flush-ysu-buffer
  }
}

# Format and display alias suggestion message
fn ysu-message {|alias-type command alias-arg|
  # Properly format message with styled segments
  var message = ""
  var part1 = (styled "Found existing "$alias-type" for " yellow bold)
  var part2 = (styled "\""$command"\"" magenta bold)
  var part3 = (styled ". You should use: " yellow bold)
  var part4 = (styled "\""$alias-arg"\"" magenta bold)
  
  # Combine parts into final message using elvish's put-based concatenation
  set message = (put $part1$part2$part3$part4)
  
  write-ysu-buffer $message"\n"
}

# Check hardcore mode (warn but can't prevent execution in after-command)
fn check-ysu-hardcore {
  if (not-eq $E:YSU_HARDCORE "") {
    write-ysu-buffer (styled "You Should Use hardcore mode enabled. Use your aliases!" red bold)"\n"
  }
}

# Convert alias:list to a more searchable map
fn get-alias-map {
  var alias-map = [&]
  
  # alias:list prints aliases as: alias:new name command
  var aliases = [(alias:list | each {|line|
    # Remove the leading "alias:new" prefix
    var cleaned = (str:trim-prefix $line "alias:new ")
    # Split into name and command (name is the first word, rest is command)
    var parts = [(str:split &max=2 " " $cleaned)]
    if (== (count $parts) 2) {
      put [$parts[0] $parts[1]]  # Return [name cmd] pair
    } else {
      put [$parts[0] ""]  # Just the name with empty command
    }
  })]
  
  each {|alias|
    var name = $alias[0]
    var cmd = $alias[1]
    set alias-map[$name] = $cmd
  } $aliases
  
  put $alias-map
}

# Check if the command could have used an alias
fn check-aliases {|typed|
  # Skip if command starts with sudo
  if (str:has-prefix $typed "sudo ") {
    return
  }
  
  var found-aliases = []
  var best-match = ""
  var best-match-value = ""
  
  # Get all aliases as a map for faster lookup
  var alias-map = (get-alias-map)
  
  # Get ignored aliases if set
  var ignored-aliases = []
  if (not-eq $E:YSU_IGNORED_ALIASES "") {
    set ignored-aliases = [$E:YSU_IGNORED_ALIASES]
  }
  
  # Check each alias against the typed command
  var keys = [(keys $alias-map)]
  for name $keys {
    var cmd = $alias-map[$name]
    
    # Skip ignored aliases
    if (has-value $ignored-aliases $name) {
      continue
    }
    
    # Check if command matches the alias value
    if (or (eq $typed $cmd) (str:has-prefix $typed $cmd" ")) {
      # If the alias command is longer than the alias name
      if (> (count $cmd) (count $name)) {
        set found-aliases = [$@found-aliases $name]
        
        # Track best match (longest command or shortest alias on tie)
        if (> (count $cmd) (count $best-match-value)) {
          set best-match = $name
          set best-match-value = $cmd
        } elif (and (== (count $cmd) (count $best-match-value)) (< (count $name) (count $best-match))) {
          set best-match = $name
          set best-match-value = $cmd
        }
      }
    }
  }
  
  # Display results based on mode setting
  var mode = $E:YSU_MODE
  if (eq $mode "") {
    set mode = "BESTMATCH"  # Default mode
  }
  
  if (eq $mode "ALL") {
    # Show all possible aliases
    for name $found-aliases {
      ysu-message "alias" $alias-map[$name] $name
    }
  } elif (eq $mode "BESTMATCH") {
    # Show only the best match
    if (not-eq $best-match "") {
      # Don't remind if they already typed the alias
      if (and (not-eq $typed $best-match) (not (str:has-prefix $typed $best-match" "))) {
        ysu-message "alias" $alias-map[$best-match] $best-match
      }
    }
  }
  
  if (> (count $found-aliases) 0) {
    check-ysu-hardcore
  }
}

# Check for git aliases
fn check-git-aliases {|typed|
  # Skip if not a git command or starts with sudo
  if (or (not (str:has-prefix $typed "git ")) (str:has-prefix $typed "sudo ")) {
    return
  }
  
  var found = $false
  var git-cmd = (str:trim-prefix $typed "git ")
  
  # Get git aliases if git is available
  if (has-external git) {
    try {
      var git-aliases = [(e:git config --get-regexp "^alias\\..+$" | each {|line|
        # Parse git config output
        var parts = [(str:split " " $line 2)]
        if (== (count $parts) 2) {
          var key = (str:trim-prefix $parts[0] "alias.")
          var value = $parts[1]
          put [$key $value]
        }
      })]
      
      for alias $git-aliases {
        var key = $alias[0]
        var value = $alias[1]
        
        if (or (eq $git-cmd $value) (str:has-prefix $git-cmd $value" ")) {
          ysu-message "git alias" $value "git "$key
          set found = $true
        }
      }
      
      if $found {
        check-ysu-hardcore
      }
    } catch e {
      # Silently ignore git errors
    }
  }
}

# Main hook function that runs after each command
fn ysu-after-command {|m|
  # Get the command that was just executed
  var cmd = $m[src][code]
  
  # Check for possible alias usage
  check-aliases $cmd
  check-git-aliases $cmd
  
  # Make sure to flush the buffer if position is "after"
  flush-ysu-buffer
}

# Function to disable the plugin
fn disable-you-should-use {
  set edit:after-command = [ ]

  echo (styled "You-Should-Use disabled" yellow)
}

# Function to enable the plugin
fn enable-you-should-use {
  set edit:after-command = [ {|m| ysu-after-command $m} ]
  # echo (styled "You-Should-Use enabled" green)
}

# Initialize
enable-you-should-use