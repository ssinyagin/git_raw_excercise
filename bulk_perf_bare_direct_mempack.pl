use strict;
use warnings;
use Digest::SHA qw(sha1_hex);
use File::Spec::Functions qw(catfile);
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


my $json = JSON->new;
$json->canonical(1);


my $repodir1 = $homedir . '/r1';

foreach my $dir ($repodir1)
{
    remove_tree($dir);
}



my $ts_start = time();
my $prev_ts = $ts_start;


## Producer repo
my $r1 = Git::Raw::Repository->init($repodir1, 1);
my $mempack = Git::Raw::Mempack->new;
my $odb = $r1->odb;
$odb->add_backend($mempack, 99);

my $odb_path = catfile($r1->path, 'objects', 'pack');

{
    my $config = $r1->config();
    $config->int('core.bigFileThreshold', 1);
    $config->int('core.compression', 0);
    $config->int('core.looseCompression', 0);
    
    my $index = $r1->index;
    my $tree = $index->write_tree;
    my $me = _signature();
    $r1->commit('First empty commit', $me, $me, [], $tree);
    _create_packfile();

    my $branch = Git::Raw::Branch->lookup( $r1, 'master', 1 );
    $branch->move('DataTree', 1);
}

_print_time('Created r1 repo');

_gen_data_r1($count, 0, 'First large commit');
_read_data();

print "Not writing anything\n";
_gen_data_r1(0, 0, 'not writing anything');
_read_data();

_gen_data_r1($count, 0, 'Overwrite the same files with the same data');
_read_data();


_gen_data_r1($count, $count, 'Second large commit');
_read_data();


# Delete some files
{
    my $i = 0;
    my $n_delete = int($count/3);
    printf("Deleting %d files\n", $n_delete);

    my $index = $r1->index;
    while( $i < $n_delete )
    {
        my $fname = _data_file_name($i);
        if( not $index->find($fname) )
        {
            printf("Cannot find an entry for %d: %s\n", $i, $fname);
        }
        else
        {
            $index->remove($fname);
        }
        $i++;
    }

    _print_time('index->remove');
    my $tree = $index->write_tree();
    _print_time('index->write_tree');
    my $me = _signature();
    my $head = $r1->head->target;
    my $msg = sprintf('Deleted %d files', $n_delete);
    $r1->commit($msg, $me, $me, [$head], $tree);
    _create_packfile();
    _print_time('Commit: ' . $msg);
}

_read_data();




sub _signature
{
    return Git::Raw::Signature->now('Z', 'x@x.com');
}



sub _print_time
{
    my $msg = shift;
    my $now = time();
    printf("%f (%f) %s\n", $now - $ts_start, $now - $prev_ts, $msg);
    $prev_ts = $now;
}



sub _data_file_name
{
    my $n = shift;
    my $sha = sha1_hex(sprintf(' %d ', $n));
    return substr($sha, 0, 2) . '/' .
        substr($sha, 2, 2) . '/' .
        substr($sha, 4);
}




sub _gen_data_r1
{
    my $n_nodes = shift;
    my $n_start = shift;
    my $msg = shift;

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

    
    my $index = $r1->index();

    my $cnt = 0;
    while( $cnt < $n_nodes )
    {
        $data->{'counter'} = $cnt;
        
        my $fname = _data_file_name($cnt+$n_start);
        $index->add_frombuffer(_data_file_name($cnt+$n_start),
                               $json->encode($data));
        $cnt++;
    }

    _print_time(sprintf
                ('Wrote JSON data to a tree in r1: %d nodes, starting from %d',
                 $n_nodes, $n_start));

    my $tree = $index->write_tree();
    _print_time('index->write_tree');
    
    my $me = _signature();
    my $head = $r1->head->target;
    $r1->commit($msg, $me, $me, [$head], $tree);
    _print_time('Commit: ' . $msg);
    _create_packfile();
    _print_time('Indexed packfile');
}


my $prev_tree;

sub _create_packfile
{
    my $tp = Git::Raw::TransferProgress -> new;
    my $indexer = Git::Raw::Indexer->new($odb_path, $odb);
    $indexer->append($mempack->dump($r1), $tp);
    $indexer->commit($tp);
    $mempack->reset;
}

sub _read_data
{
    my $count_read = 0;
    my $count_deleted = 0;

    my $branch = Git::Raw::Branch->lookup($r1, 'DataTree', 1);    
    die("Cannot lookup branch") unless defined($branch);
    
    my $head_tree = $branch->peel('tree');
    
    if( not defined($prev_tree) )
    {
        printf("Previous commit is undefined, reading the whole tree\n");

        foreach my $entry ($head_tree->entries())
        {
            $count_read += _read_entry($entry);
        }
    }
    else
    {
        printf("Reading a delta from previous commit\n");
        
        my $diff = $prev_tree->diff(
            {'tree' => $head_tree,
             'flags' => {
                 'skip_binary_check' => 1,
             },
            });
        
        my @deltas = $diff->deltas();
        foreach my $delta (@deltas)
        {
            my $path = $delta->new_file()->path();
            
            if ($delta->status() ne 'deleted')
            {
                my $entry = $head_tree->entry_bypath($path);
                my $subdir = substr($path, 0, rindex($path, '/'));
                $count_read += _read_entry($entry, $subdir);
            }
            else
            {
                # print "[$path] REMOVED!\n";
                $count_deleted++;
            }
        }
    }

    $prev_tree = $head_tree;
    
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
