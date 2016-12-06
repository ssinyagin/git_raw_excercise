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
my $count = $ARGV[1];

if( not $homedir or not $count )
{
    print STDERR "Usage: $0 DIR COUNT\n";
    exit(1);
}


my $repodir1 = $homedir . '/r1';
my $repodir2 = $homedir . '/r2';

foreach my $dir ($repodir1, $repodir2)
{
    remove_tree($dir);
}

sub _signature
{
    return Git::Raw::Signature->now('Z', 'x@x.com');
}

my $updated_files = {};

my $checkout_progress_cb = sub {
    my $file = shift;
    my $completed_steps = shift;
    my $total_steps = shift;
    if( defined($file) ) {
        $updated_files->{$file} = 1;
    }
    return 0;
};


my $checkout_opts = {
    'checkout_strategy' => {'safe' => 1},
    'callbacks' => {'progress' => $checkout_progress_cb},
};

sub _print_updates
{
    printf("Total %d updates\n", scalar(keys %{$updated_files}));
}


my $ts_start = time();
my $prev_ts = $ts_start;

sub _print_time
{
    my $msg = shift;
    my $now = time();
    printf("%f (%f) %s\n", $now - $ts_start, $now - $prev_ts, $msg);
    $prev_ts = $now;
}
    

## Producer repo
my $r1 = Git::Raw::Repository->init($repodir1, 0);

{
    my $index = $r1->index;
    $index->write;
    my $tree = $index->write_tree;

    my $me = _signature();

    $r1->commit('First empty commit', $me, $me, [], $tree);

    my $branch = Git::Raw::Branch->lookup( $r1, 'master', 1 );
    $branch->move('DataTree', 1);
}

_print_time('Created r1 repo');

## Consumer repo
my $r2 = Git::Raw::Repository->init($repodir2, 0);
{
    my $config = $r2->config();
    $config->str('remote.origin.url', 'file://' . $repodir1);
    $config->str('remote.origin.fetch',
                 '+refs/heads/DataTree:refs/remotes/origin/DataTree');
    
    $config->str('branch.DataTree.remote', 'origin');
    $config->str('branch.DataTree.merge', 'refs/heads/DataTree');

    my $remote = Git::Raw::Remote->load($r2, 'origin');
    $remote->fetch();

    my $ref = Git::Raw::Reference->lookup('remotes/origin/DataTree', $r2);
    die('REF') unless defined($ref);
    my $branch = $r2->branch('DataTree', $ref->target);
    $r2->head($branch);
    $r2->checkout($branch, $checkout_opts);
    _print_updates();
}

_print_time('Created r2 repo');



my $data = {
    'docsIfDownstreamChannelTable' => '1.3.6.1.2.1.10.127.1.1.1',
    'docsIfCmtsDownChannelCounterTable' => '1.3.6.1.2.1.10.127.1.3.10',
    'docsIfSigQSignalNoise' => '1.3.6.1.2.1.10.127.1.1.4.1.5',
    'ciscoLS1010'                       => '1.3.6.1.4.1.9.1.107',
    'ciscoImageTable'                   => '1.3.6.1.4.1.9.9.25.1.1',
    'ceImageTable'                      => '1.3.6.1.4.1.9.9.249.1.1.1',
    'bufferElFree'                      => '1.3.6.1.4.1.9.2.1.9.0',
    'cipSecGlobalHcInOctets'            => '1.3.6.1.4.1.9.9.171.1.3.1.4.0',
    'cbgpPeerAddrFamilyName'            => '1.3.6.1.4.1.9.9.187.1.2.3.1.3',
    'cbgpPeerAcceptedPrefixes'          => '1.3.6.1.4.1.9.9.187.1.2.4.1.1',
    'cbgpPeerPrefixAdminLimit'          => '1.3.6.1.4.1.9.9.187.1.2.4.1.3',
    'ccarConfigType'                    => '1.3.6.1.4.1.9.9.113.1.1.1.1.3',
    'ccarConfigAccIdx'                  => '1.3.6.1.4.1.9.9.113.1.1.1.1.4',
    'ccarConfigRate'                    => '1.3.6.1.4.1.9.9.113.1.1.1.1.5',
    'ccarConfigLimit'                   => '1.3.6.1.4.1.9.9.113.1.1.1.1.6',
    'ccarConfigExtLimit'                => '1.3.6.1.4.1.9.9.113.1.1.1.1.7',
    'ccarConfigConformAction'           => '1.3.6.1.4.1.9.9.113.1.1.1.1.8',
    'ccarConfigExceedAction'            => '1.3.6.1.4.1.9.9.113.1.1.1.1.9',
    'cvpdnSystemTunnelTotal'            => '1.3.6.1.4.1.9.10.24.1.1.4.1.2',
    'c3gStandard'                       => '1.3.6.1.4.1.9.9.661.1.1.1.1',
    'cportQosDropPkts'                  => '1.3.6.1.4.1.9.9.189.1.3.2.1.7',
};

my $json = JSON->new;

while( $count-- > 0 )
{
    my $sha = sha1_hex(' ' . $count . ' ');

    my $dir = $repodir1 . '/' . substr($sha, 0, 2) . '/' .
        substr($sha, 2, 2) . '/';

    if( not -d $dir )
    {
        make_path($dir) or die("Cannot mkdir $dir: $!");
    }
    
    my $filepath = $dir . $sha;
       
    my $fh = IO::File->new($filepath, 'w') or die("Cannot open $filepath: $!");
    $fh->print($json->encode($data));
    $fh->close;
}

_print_time('Wrote JSON data');

# produce one large commit
{
    my $index = $r1->index;
    $index->add_all({});
    $index->write;
    my $tree = $index->write_tree();
    my $me = _signature();
    my $head = $r1->head->target;
    $r1->commit('Big data commit', $me, $me, [$head], $tree);
}


_print_time('Made a large commit');


# pull it into r2
{
    my $branch = Git::Raw::Branch->lookup($r2, 'DataTree', 1);    
    die("Cannot lookup branch") unless defined($branch);
    
    my $remote = Git::Raw::Remote->load($r2, $branch->remote_name());
    die('X3') unless defined($remote);
    
    $remote->fetch();
    _print_time('Fetch the large commit');    

    my $ref = Git::Raw::Reference->lookup('remotes/origin/DataTree', $r2 );
    die('REF3') unless defined($ref);

    my $analysis = $r2->merge_analysis($ref);
    die("Only supports fast-forward merges at this time")
        if (!grep {$_ eq 'fast_forward'} @$analysis);

    _print_time('merge_analysis');    
    
    my $commit = $ref->peel('commit');
    my $tree = $commit->tree();
    my $index = $r2->index();
    
    $index->read_tree($tree);
    _print_time('index->read_tree');    

    $index->write();
    _print_time('index->write');    

    $r2->checkout($tree, $checkout_opts);
    _print_time('checkout');    
    $r2->head($branch->target($commit));
    _print_time('move head');    
    
    _print_updates();
}

# read JSON data

my $d0 = IO::Dir->new($repodir2) or die($!);

while( defined(my $dir0 = $d0->read()) )
{
    if( $dir0 =~ /^\w{2}$/ )
    {
        my $path1 = $repodir2 . '/' . $dir0;
        my $d1 = IO::Dir->new($path1) or die($!);

        while( defined(my $dir1 = $d1->read()) )
        {
            if( $dir1 =~ /^\w{2}$/ )
            {
                my $path2 = $path1 . '/' . $dir1;
                my $d2 = IO::Dir->new($path2) or die($!);

                while( defined(my $fname = $d2->read()) )
                {
                    if( $fname =~ /\w/ )
                    {
                        local $/;
                        my $filepath = $path2 . '/' . $fname;
                        my $fh = IO::File->new($filepath)
                            or die("Cannot open $filepath: $!");

                        my $data = $json->decode($fh->getline);
                        die("empty data") unless defined($data);
                        die("not a hash") unless ref($data) eq 'HASH';
                        
                        $fh->close;
                    }
                }
            }
        }
    }
}

_print_time('Read JSON');    
