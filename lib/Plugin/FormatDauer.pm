package Plugin::FormatDauer;

use Template::Plugin::Filter;
use base qw( Template::Plugin::Filter );

sub filter {
     my ($self, $text) = @_;
     my $number = sprintf("%.5f", $text);
     return $number;
}

1;