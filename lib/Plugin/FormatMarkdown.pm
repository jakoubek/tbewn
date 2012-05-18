package Plugin::FormatMarkdown;

use Template::Plugin::Filter;
use base qw( Template::Plugin::Filter );

use Text::Markdown 'markdown';

sub filter {
     my ($self, $text) = @_;
     return markdown($text);
}

1;