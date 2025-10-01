#alias:new swapFiles Usage: swapFiles file1 file2
edit:add-var swapFiles~ {|file1 file2|
    echo "Swapping $file1 and $file2"
    var file1_dir = (dirname $file1)
    if (eq $file1_dir $file1) {
        set file1_dir = "."
    }
    var tmpfile = (mktemp -p $file1_dir)
    mv $file1 $tmpfile
    mv $file2 $file1
    mv $tmpfile $file2
}
