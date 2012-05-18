package Plugin::FormatDate;

use Template::Plugin::Filter;
use base qw( Template::Plugin::Filter );

use DateTime;

sub filter {
     my ($self, $text) = @_;
     my $dt = DateTime->from_epoch( epoch => $text, time_zone  => 'Europe/Berlin', );
     return $dt->ymd('-') . ' ' . $dt->hms(':');
}

1;