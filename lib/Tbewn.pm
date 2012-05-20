package Tbewn;
use Dancer ':syntax';
use Dancer::Plugin::Cache::CHI;

use File::Slurp qw(read_file write_file);
use Encode      qw(encode decode);
use Time::HiRes qw(gettimeofday);

our $VERSION = '0.1';

#check_page_cache;

hook 'before' => sub {
    var appname => config->{appname};
    var website => config->{website};
    my $revision = -e 'revision' ? read_file 'revision' : '{}';
    var commitid => $revision;
    var revision => substr($revision, 0, 7);
};

get '/' => sub {
    my $before = gettimeofday;
    #my $data = cache->compute( 'startseite', '5min', sub { get_startseite() } );
    my $data = get_startseite();
    my $authors = get_authors();
    my $tags = get_tags();
    my $anzahl = keys %{$data};
    my $elapsed = gettimeofday - $before;
    template 'index', {data => $data, authorlist => $authors->{'list'}, taglist => $tags->{'list'}, anzahl => $anzahl, dauer => $elapsed};
};

get '/search' => sub {
    my $before = gettimeofday;
    my $query = param('q');

    if ($query eq '') {
        redirect '/';
    }

    #my $data = cache->compute( 'startseite', '5min', sub { get_startseite() } );
    my $data = get_startseite();

    my %result;
    while (my ($key, $value) = each %$data) {
        if ($value->{title} =~ m/$query/i || $value->{text} =~ m/$query/i) {
            $result{$key} = {
                title => $value->{title},
                text  => $value->{text},
            }
        }
    }
   
    my $anzahl = keys %result;
    my $elapsed = gettimeofday - $before;
    template 'index', {data => \%result, anzahl => $anzahl, dauer => $elapsed};
};

get '/a/:authorid' => sub {
    my $before = gettimeofday;
    my $author_id = param('authorid');
    my $authors = get_authors();
    my $tags = get_tags();
    my $data = get_startseite();

    my %result;
    while (my ($key, $value) = each %$data) {
        if (defined $value->{author} && $value->{author} =~ m/$author_id/i) {
            $result{$key} = {
                title => $value->{title},
                text  => $value->{text},
            }
        }
    }

    my $anzahl = keys %result;
    my $elapsed = gettimeofday - $before;
    template 'index', {data => \%result, authorlist => $authors->{'list'}, taglist => $tags->{'list'}, anzahl => $anzahl, dauer => $elapsed, author_id => $author_id};
};

get '/-:id' => sub {
    my $before = gettimeofday;
    my $filename = config->{data}{json};
    my $json = -e $filename ? read_file $filename : '{}';
    my $data = from_json encode('UTF-8', $json);
    my $id = param('id');
    my $elapsed = gettimeofday - $before;
    template 'entry', {data => $data->{$id}, id => $id, dauer => $elapsed};
};

get '/add' => sub {
    template 'add';
};

post '/add' =>  sub {
    my $filename = config->{data}{json};
    my $json = -e $filename ? read_file $filename : '{}';
    my $data = from_json encode('UTF-8', $json);
    my $now   = time;
    $data->{$now} = {
      title => params->{title},
      text  => params->{text},
      author => params->{author},
      format => (defined params->{format}) ? params->{format} : 'plain',
    };

    write_file $filename, to_json($data);
    cache->remove('startseite');
    generate_metadata();
    redirect '/';
};

get '/-:id/edit' => sub {
    my $before = gettimeofday;
    my $data = get_startseite();
    my $id = param('id');
    my $elapsed = gettimeofday - $before;
    template 'edit', {data => $data->{$id}, id => $id, dauer => $elapsed};
};

post '/edit' => sub {
    my $data = get_startseite();
    my $id = param('id');
    $data->{$id} = {
      title => params->{title},
      text  => params->{text},
      author => params->{author},
      format => (defined params->{format}) ? params->{format} : 'plain',
    };
    my $filename = config->{data}{json};
    write_file $filename, to_json($data);
    generate_metadata();
    redirect '/';
};

post '/delete' => sub {
    my $id = param('id');
    my $filename = config->{data}{json};
    my $json = -e $filename ? read_file $filename : '{}';
    my $data = from_json encode('UTF-8', $json);
    delete $data->{$id};
    write_file $filename, to_json($data);
    cache->remove('startseite');
    generate_metadata();
    redirect '/';
};

get '/about' => sub {
    my $about_id = config->{special_sites}{about};
    redirect '/-'.$about_id;
};

get '/clear-cache' => sub {
    cache->clear();
    redirect '/';
};

get '/generate-metadata' => sub {
    generate_metadata();
    redirect '/';
};

get '/tags' => sub {
    my $before = gettimeofday;
    #my $data = cache->compute( 'startseite', '5min', sub { get_startseite() } );
    my $tags = get_tags();
    my $anzahl = keys %{$tags};
    my $elapsed = gettimeofday - $before;
    template 'tags', {taglist => $tags->{'list'}, tags => $tags->{'entries'}, anzahl => $anzahl, dauer => $elapsed};
};

get '/t/:tagname' => sub {
    my $before = gettimeofday;
    my $tagname = params->{'tagname'};
    my $authors = get_authors();
    my $tags = get_tags();

    my @taglist = @{$tags->{'list'}};
    if (grep $_ eq $tagname, @taglist) {

        my @entries = @{$tags->{'entries'}->{$tagname}->{'entries'}};
        my %entries_h;
        foreach my $e (@entries) {
            debug("+ $e");
            $entries_h{$e} = 1;
        }

        my $data = get_startseite();

        my %result;
        while (my ($key, $value) = each %$data) {
            debug($key);
            if (exists $entries_h{$key}) {
                debug("GEFUNDEN");
                $result{$key} = $value;
            }
        }

        my $anzahl = scalar @entries;
        debug("found $anzahl");
        my $elapsed = gettimeofday - $before;
        template 'index', {data => \%result, authorlist => $authors->{'list'}, taglist => $tags->{'list'}, anzahl => $anzahl, dauer => $elapsed};

    } else {
        redirect '/';
    }

};

true;

sub get_startseite {
    my $filename = config->{data}{json};
    my $json = -e $filename ? read_file $filename : '{}';
    my $data = from_json encode('UTF-8', $json);
    return $data;
}

sub get_authors {
    my $filename = config->{data}{authors};
    my $json = -e $filename ? read_file $filename : '{}';
    my $data = from_json encode('UTF-8', $json);
    return $data;
}

sub get_tags {
    my $filename = config->{data}{tags};
    my $json = -e $filename ? read_file $filename : '{}';
    my $data = from_json encode('UTF-8', $json);
    return $data;
}

sub generate_metadata {
    my $authorsfile = config->{data}{authors};
    my $tagsfile = config->{data}{tags};
    
    my $data = get_startseite();
    
    my %authors;
    my %tag_count;
    my %tag_entries;
    
    while (my ($key, $value) = each %$data) {
        debug("Eintrag #" . $key);
        if (defined $value->{'author'}) {
            $authors{$value->{'author'}}++;
        }
        my @matches = ($value->{text} =~ m/t:(\w*)/g);
        debug(scalar @matches . "Tags gefunden");
        foreach my $tag (@matches) {
            if ($tag ne '') {
                $tag = lc $tag;
                $tag_count{$tag}++;
                push @{$tag_entries{$tag}}, $key;
                debug("Tag: $tag");
            }
        }        
    }

    my @authors = keys %authors;
    my $authordata->{'list'} = \@authors;

    my $tagdata;
    while (my ($key, $value) = each %tag_count) {
        $tagdata->{'entries'}->{$key} = {
            count => $value,
            entries => \@{$tag_entries{$key}},
        };
    }
    my @taglist = keys %tag_count;
    $tagdata->{'list'} = \@taglist;

    write_file $authorsfile, to_json($authordata);
    write_file $tagsfile, to_json($tagdata);

}