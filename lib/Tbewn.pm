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
    my $anzahl = keys %{$data};
    my $elapsed = gettimeofday - $before;
    template 'index', {data => $data, anzahl => $anzahl, dauer => $elapsed};
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

true;

sub get_startseite {
    my $filename = config->{data}{json};
    my $json = -e $filename ? read_file $filename : '{}';
    my $data = from_json encode('UTF-8', $json);
    return $data;
}