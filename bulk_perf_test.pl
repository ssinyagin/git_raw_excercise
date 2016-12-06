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



my $ts_start = time();
my $prev_ts = $ts_start;
    

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

_gen_data_r1($count, 0);

# produce one large commit
_commit_all_r1('First large commit');
_pull_r2();
_read_data($repodir2, $updated_files);

# Overwrite the same files wioth the same data
_gen_data_r1($count, 0);

_commit_all_r1('This should be empty commit');
_pull_r2();
_read_data($repodir2, $updated_files);



sub _signature
{
    return Git::Raw::Signature->now('Z', 'x@x.com');
}

sub _print_updates
{
    printf("Total %d updates\n", scalar(keys %{$updated_files}));
}


sub _print_time
{
    my $msg = shift;
    my $now = time();
    printf("%f (%f) %s\n", $now - $ts_start, $now - $prev_ts, $msg);
    $prev_ts = $now;
}


sub _gen_data_r1
{
    my $n_nodes = shift;
    my $n_start = shift;

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
    $json->canonical(1);
    
    my $cnt = 0;
    while( $cnt++ < $n_nodes )
    {
        my $sha = sha1_hex(' ' . ($cnt+$n_start) . ' ');

        my $dir = $repodir1 . '/' . substr($sha, 0, 2) . '/' .
            substr($sha, 2, 2) . '/';
        
        if( not -d $dir )
        {
            make_path($dir) or die("Cannot mkdir $dir: $!");
        }
        
        my $filepath = $dir . $sha;
        
        my $fh = IO::File->new($filepath, 'w')
            or die("Cannot open $filepath: $!");
        $fh->print($json->encode($data));
        $fh->close;
    }
    
    _print_time(sprintf('Wrote JSON data to r1: %d nodes, starting from %d',
                        $n_nodes, $n_start));
}



sub _commit_all_r1
{
    my $msg = shift;
    
    my $index = $r1->index;
    $index->add_all({});
    $index->write;
    my $tree = $index->write_tree();
    my $me = _signature();
    my $head = $r1->head->target;
    $r1->commit($msg, $me, $me, [$head], $tree);
    _print_time('Commit: ' . $msg);
}


sub _pull_r2
{
    my $branch = Git::Raw::Branch->lookup($r2, 'DataTree', 1);    
    die("Cannot lookup branch") unless defined($branch);
    
    my $remote = Git::Raw::Remote->load($r2, $branch->remote_name());
    die('X3') unless defined($remote);
    
    $remote->fetch();
    _print_time('Fetch');    

    my $ref = Git::Raw::Reference->lookup('remotes/origin/DataTree', $r2 );
    die('REF3') unless defined($ref);

    my $analysis = $r2->merge_analysis($ref);
    die("Only supports fast-forward merges at this time")
        if (!grep {$_ eq 'fast_forward'} @$analysis);

    my $commit = $ref->peel('commit');
    my $tree = $commit->tree();
    my $index = $r2->index();
    
    $index->read_tree($tree);
    $index->write();
    $r2->checkout($tree, $checkout_opts);
    $r2->head($branch->target($commit));

    _print_time('Checkout');        
    _print_updates();
}

    


sub _read_data
{
    my $dir = shift;
    my $files = shift;

    my $count_read = 0;
    my $count_deleted = 0;
    my $json = JSON->new;
    
    while( my ($fname, $dummy) = each %{$files} )
    {
        my $filename = $dir . '/' . $fname;
        if( -e $filename )
        {
            local $/;
            my $fh = IO::File->new($filename)
                or die("Cannot open $filename: $!");

            my $data = $json->decode($fh->getline);
            die("empty data") unless defined($data);
            die("not a hash") unless ref($data) eq 'HASH';
            
            $fh->close;
            $count_read++;
        }
        else
        {
            $count_deleted++;
        }
    }

    _print_time(sprintf('Read %d files, deleted %d files',
                        $count_read, $count_deleted));    
}


