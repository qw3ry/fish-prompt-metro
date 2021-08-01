# git helper functions
# unused
function __git_is_repo -d "Test if the current directory is a Git repository"
    if not command git rev-parse --git-dir > /dev/null 2>/dev/null
        return 1
    end
end
# unused
function __git_repository_root -d "Get the top level directory of the current git repository"
    __git_is_repo; and command git rev-parse --show-toplevel
end
# unused
function __git_is_empty -d "Test if a repository is empty"
    git_is_repo; and test -z (command git rev-list -n 1 --all 2>/dev/null)
end
# unused
function __git_is_tag -d "Test if HEAD is on top of a tag (can be simple, annotated or signed)"
    __git_is_detached_head; and command git describe --tags --exact-match HEAD 2>/dev/null > /dev/null
end

function __git_ahead -a ahead behind diverged none
    command git rev-list --count --left-right "@{upstream}...HEAD" 2>/dev/null | command awk "
        /^0\t0/         { print \"$none\"       ? \"$none\"     : \"\";     exit 0 }
        /^[0-9]+\t0/    { print \"$behind\"     ? \"$behind\"   : \"-\";    exit 0 }
        /^0\t[0-9]+/    { print \"$ahead\"      ? \"$ahead\"    : \"+\";    exit 0 }
        //              { print \"$diverged\"   ? \"$diverged\" : \"±\";    exit 0 }
    "
end

function __git_branch_name -d "Get the name of the current Git branch, tag or sha1"
    set -l branch_name (command git symbolic-ref --short HEAD 2>/dev/null)

    if test -z "$branch_name"
        set -l tag_name (command git describe --tags --exact-match HEAD 2>/dev/null)

        if test -z "$tag_name"
            command git rev-parse --short HEAD 2>/dev/null
        else
            printf "%s\n" "$tag_name"
        end
    else
        printf "%s\n" "$branch_name"
    end
end

function __git_is_staged -d "Test if there are changes staged for commit"
    not command git diff --cached --no-ext-diff --quiet --exit-code 2>/dev/null
end

function __git_is_dirty -d "Test if there are changes not staged for commit"
    not command git diff --no-ext-diff --quiet --exit-code 2>/dev/null
end

function __git_untracked_files -d "Get the number of untracked files in a repository"
    git_is_repo; and command git ls-files --others --exclude-standard | command awk '
        BEGIN { n = 0 }
        { n++ }
        END {
            print n
            exit !n
        }'
end

function __git_has_untracked -d "Test if there are any untracked files in the working tree"
    test "0" != (__git_untracked_files)
end
function __git_is_detached_head -d "Test if the repository is in a detached HEAD state"
    not command git symbolic-ref HEAD 2>/dev/null > /dev/null
end
function __git_is_stashed -d "Test if there are changes in the Git stash"
    command git rev-parse --verify --quiet refs/stash > /dev/null 2>/dev/null
end
function __git_is_touched -d "Test if there are any changes in the working tree"
    __git_is_staged; or __git_is_dirty
end

################################################################33
# prompt function
################################################################33
function fish_prompt
    set -l status_copy $status
    set -l pwd_info (pwd_info "/")
    set -l dir
    set -l base

    set -l dark_mode 1 #default to dark mode
    set -l base_color
    set -l text_color
    set -l split_color

    if functions -q is_dark_mode
        is_dark_mode; or set -e dark_mode
    end
    if set -lq dark_mode
        set base_color BBB 333
        set text_color white
        # set split_color 000
    else
        set base_color 555 DDD
        set text_color black
        # set split_color FFF
    end
    set split_color $base_color[2]

    if test "$PWD" = ~
        set base "~"

    else if pwd_is_home
        set dir "~/"
    else
        if test "$PWD" != /
            set dir "/"
        end

        set base (set_color red)"/"
    end

    if test ! -z "$pwd_info[1]"
        set base "$pwd_info[1]"
    end

    if test ! -z "$pwd_info[2]"
        set dir "$dir$pwd_info[2]/"
    end

    if test ! -z "$pwd_info[3]"
        segment $base_color " $pwd_info[3] "
    end

    if set branch_name (__git_branch_name)
        set -l git_color $text_color green
        set -l git_glyph ""

        if __git_is_staged
            set git_color $text_color yellow

            if __git_is_dirty
                set git_color $git_color $text_color red
            end

        else if __git_is_dirty
            set git_color $text_color red

        else if __git_is_touched
            set git_color $text_color red

        else if __git_has_untracked
            set git_color $text_color blue
        end

        if __git_is_detached_head
            set git_glyph "➤"

        else if __git_is_stashed
            set git_glyph "╍╍"
        end

        set -l prompt
        set -l git_ahead (__git_ahead "+ " "- " "+- ")

        if test "$branch_name" = master -o "$branch_name" = main
            set prompt " $git_glyph $git_ahead"
        else
            set prompt " $git_glyph $branch_name $git_ahead"
        end

        if set -q git_color[3]
            segment "$git_color[3]" "$git_color[4]" "$prompt"
            segment $split_color $split_color
            segment "$git_color[1]" "$git_color[2]" " $git_glyph "
        else
            segment "$git_color[1]" "$git_color[2]" "$prompt"
        end
    end

    segment $base_color " $dir"(set_color $text_color)"$base "

    if test ! -z "$SSH_CLIENT"
        set -l color bbb 222

        if test 0 -eq (id -u "$USER")
            set color red 222
        end

        segment $color (host_info " usr@host ")

    else if test 0 -eq (id -u "$USER")
        segment red 222 " \$ "
    end

    if test "$status_copy" -ne 0
        segment red white (set_color -o)" ! "(set_color normal)

    else if last_job_id > /dev/null
        segment white 333 " %% "
    end

    if [ "$theme_display_virtualenv" != 'no' ]; and set -q VIRTUAL_ENV
        segment yellow blue " "(basename "$VIRTUAL_ENV")" "
    end

    if [ "$theme_display_ruby" != 'no' ]; and set -q RUBY_VERSION
        segment red fff " "(basename "$RUBY_VERSION")" "
    end

    if test "$fish_key_bindings" = "fish_vi_key_bindings"
      switch $fish_bind_mode
        case default
          segment white red "[N]"
        case insert
          segment black green "[I]"
        case replace-one
          segment yellow blue "[R]"
        case visual
          segment white magenta "[V]"
      end
    end

    segment_close
end
