my $indent = 2;
my $level = -2;
my $ignore = 0;
my $was_end = 0;
my@html;

open(my $fh, '<', "$ARGV[0]") or die;

while (<$fh>) {
    chomp;
    s/^\s*//;
    while (m,(<(/)?.+>)|([^<>]+),g) {
        $level += defined $2 ? -$indent : $indent;
        # $tag = substr($1, 0, 2) if (defined $1);
        $ignore = substr($1, 0, 2) eq '<!' or $1 eq '<br>' or $1 eq '<meta>';
        $level -= $indent if ($skip == 1 && $ignore == 1);
        $skip = $ignore > 0 ? 1 : 0;
        $level -= $indent if ($was_end == 1 && not defined $2);
        $was_end = defined $2 ? 1 : 0;
        my $line = ' ' x $level;
        $line .= "$1" if (defined $1);
        $line .= "$3" if (defined $3);
        push(@html, $line);
    }
}

close($fh);

open(my $fh, '>', "$ARGV[0]") or die;
print $fh "$_\n" for (@html);
close($fh);
