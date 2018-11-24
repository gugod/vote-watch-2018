BEGIN {
    $ENV{TZ}="Asia/Taipei"
};

use v5.14;

use FindBin;
use JSON::PP;
use HTTP::Tiny;
use File::Path qw<make_path>;
use File::Slurp qw<write_file read_file>;

my $json = JSON::PP->new->canonical->pretty;
my $watchlist = $json->decode( scalar read_file("${FindBin::Bin}/watchlist.json") );


my $http = HTTP::Tiny->new;
my @grabs = @ARGV > 0 ? @ARGV : (keys %$watchlist);

for my $k (@grabs) {
    my $urls = $watchlist->{$k};

    unless (ref($urls)) {
        $urls = [$urls];
    }
    for my $url (@$urls) {
        my ($fn) = $url =~ m{/([^/]+)\.html$};
        my $now = time;
        my ($sec, $min, $hour, $mday, $mon, $year) = gmtime(time);
        $year += 1900;
        $mon += 1;
        my $output_dir = sprintf('data/%s/%s/%04d%02d%02d%02d%02d%02d', $k, $fn, $year, $mon, $mday, $hour, $min, $sec);

        make_path($output_dir) unless -d $output_dir;

        say "$k => $url => $output_dir";
        my $res = $http->get($url);
        my $res_dump = $json->encode($res);
        write_file "${output_dir}/http-response.json", $res_dump;
        if ($res->{success}) {
            write_file "${output_dir}/page.html", $res->{content};        
        }
    }
}

chdir($FindBin::Bin);
system("git add -A data");
system(q< git commit --author 'nobody <nobody@nowhere>' --allow-empty-message -m '' >);
