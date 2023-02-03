use HTML::TreeBuilder;
use HTML::PrettyPrinter;

my $hpp = new HTML::PrettyPrinter(
    'linelength' => 130,
    'quote_attr' => 1,
    'allow_forced_nl' => 1,
    'tabify' => 0,
);

$hpp->set_nl_before(1, 'all!');
$hpp->set_nl_after(1, 'all!');
$hpp->set_force_nl(1, 'all!');

my $tree = new HTML::TreeBuilder;
$tree->parse_file("$ARGV[0]");
my $linearray_ref = $hpp->format($tree);

open(my $fh, ">", "$ARGV[0]") or die;
print $fh @$linearray_ref;
close($fh);

exit(0);
