function git_has_untracked -d "Test if there are any untracked files in the working tree"
    test "0" != (git_untracked_files)
end
