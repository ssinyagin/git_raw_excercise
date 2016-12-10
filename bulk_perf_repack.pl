use strict;
use warnings;
use Digest::SHA qw(sha1_hex);
use File::Path qw(make_path remove_tree);
use JSON;
use IO::File;
use IO::Dir;
use Git::Raw;
use Time::HiRes qw (time);

my $homedir = $ARGV[0];

if( not $homedir )
{
    print STDERR "Usage: $0 DIR COUNT\n";
    exit(1);
}


my $json = JSON->new;
$json->canonical(1);


my $repodir1 = $homedir . '/r1';

my $ts_start = time();
my $prev_ts = $ts_start;
    
my $r1 = Git::Raw::Repository->open($repodir1);

_read_data();

system(sprintf('cd %s; git repack -d', $repodir1));

_print_time('git repack finsihed');

_read_data();




sub _print_time
{
    my $msg = shift;
    my $now = time();
    printf("%f (%f) %s\n", $now - $ts_start, $now - $prev_ts, $msg);
    $prev_ts = $now;
}



sub _read_data
{
    my $count_read = 0;
    my $count_deleted = 0;

    my $branch = Git::Raw::Branch->lookup($r1, 'DataTree', 1);    
    die("Cannot lookup branch") unless defined($branch);
    
    my $head_tree = $branch->peel('tree');
    
    foreach my $entry ($head_tree->entries())
    {
        $count_read += _read_entry($entry);
    }
    
    _print_time(sprintf('Read %d files, deleted %d files',
                        $count_read, $count_deleted));
}


sub _read_entry
{
    my $entry = shift;
    my $path = shift;

    if( defined($path) )
    {
        $path .= '/' . $entry->name();
    }
    else
    {
        $path = $entry->name();
    }
    
    my $ret = 0;

    my $object = $entry->object();
    if( $object->is_blob() )
    {
        my $content = $object->content();
        my $data = $json->decode($content);
        die("empty data") unless defined($data);
        die("not a hash") unless ref($data) eq 'HASH';
        die("data does not contain counter") unless defined($data->{'counter'});
        # print $path, "\n";
        $ret = 1;
    }
    elsif( $object->is_tree() )
    {
        foreach my $child_entry ($object->entries())
	{
            $ret += _read_entry($child_entry, $path);
        }
    }
        
    return $ret;
}
