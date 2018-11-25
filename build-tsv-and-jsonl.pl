use v5.18;
use utf8;
use strict;
use warnings;

use Encode qw(encode_utf8);
use Mojo::JSON qw(encode_json);
use Mojo::DOM;
use Time::Moment;
use File::Next;
use File::Slurp qw(read_file);

sub parse_one_file {
    my ($file) = @_;

    my ($case, $division, $dom, $html, $el, $gmtime_ts, @gmtime, $taipei_time_tm);

    ($gmtime_ts) = $file =~ m{/ ([0-9]{14}) / page\.html \z}x;
    @gmtime = $gmtime_ts =~ m{\A ([0-9]{4}) ([0-9]{2}) ([0-9]{2}) ([0-9]{2}) ([0-9]{2}) ([0-9]{2}) \z}x;

    ($taipei_time_tm) = Time::Moment->new(
        offset => 0,
        year   => $gmtime[0],
        month  => $gmtime[1],
        day    => $gmtime[2],
        hour   => $gmtime[3],
        minute => $gmtime[4],
        second => $gmtime[5],
    )->with_offset_same_instant(480);

    $html = read_file( $file, binmode => ':utf8' );

    $dom = Mojo::DOM->new($html);
    $el = $dom->at('div#divContent td[valign=bottom] > b');
    ($case, $division) = $el->all_text =~ /第([0-9]+)案 公民投票結果 - (\p{Letter}+)/;

    # 同意票數, 不同意票數, 有效票數, 無效票數, 投票數, 投票權人數, 投票率(%), 有效同意票數對<br>投票權人數百分比(%)
    my $numbers = $dom->find('table.tableT tr.trT td')->map('all_text')->to_array;
    @$numbers = map { s/,//g; $_ } @$numbers; 
    # say '>>> ', join(' / ', @$numbers);

    # 已送/應送:&nbsp;18/18&nbsp;
    my @polls = $dom->at('tr.trFooterT > td')->all_text =~ m{ ([0-9]+) / ([0-9]+) }x;

    return [
        case                              => $case,
        division                          => $division,
        taipei_time_tm                    => $taipei_time_tm,
        count_of_agreeing_votes           => $numbers->[0],
        count_of_disagreeing_votes        => $numbers->[1],
        count_of_valid_votes              => $numbers->[2],
        count_of_invalid_votes            => $numbers->[3],
        count_of_votes                    => $numbers->[4],
        count_of_voters                   => $numbers->[5], 
        voting_rate                       => $numbers->[6],
        ratio_of_agreeing_votes_to_voters => $numbers->[7],
        count_of_submitted_polls          => $polls[0],
        count_of_polls                    => $polls[1],
    ]
}

sub evens {
    my $data = $_[0];
    my $i = 1;
    return [ grep { $i++ % 2 == 0 } @$data ];
}

sub MAIN {
    my $files = File::Next::files('data/referendum');

    my %out_fh;
    while ( defined( my $file = $files->() ) ) {
        next unless $file =~ /\.html \z/x;
        my $data = parse_one_file($file);
        my $data_href = { @$data };
        my $case = $data_href->{case};

        my ($fh_jsonl, $fh_tsv);
        if ($out_fh{ $case }) {
            $fh_tsv = $out_fh{ $case }{tsv};
            $fh_jsonl = $out_fh{ $case }{jsonl};
        } else {
            open $fh_jsonl, '>',  'data/referendum/case-'. $case . '.jsonl';
            open $fh_tsv, '>',  'data/referendum/case-'. $case . '.tsv';
            $out_fh{ $case }{tsv} = $fh_tsv;
            $out_fh{ $case }{jsonl} = $fh_jsonl;
            say $fh_tsv encode_utf8 join "\t", "案", "區", "時間", "同意票數", "不同意票數", "有效票數", "無效票數", "投票數", "投票權人數", "投票率(%)", "有效同意票數對投票權人數百分比(%)", "已送", "應送";
        }

        say $fh_jsonl encode_json($data_href);
        say $fh_tsv encode_utf8 join "\t", @{ evens $data };
    }
}

MAIN();
