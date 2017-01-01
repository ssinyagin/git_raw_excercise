use strict;
use warnings;

use File::Path qw(make_path remove_tree);
use Git::Raw;

my $homedir = $ARGV[0];

if( not $homedir )
{
    print STDERR "Usage: $0 DIR\n";
    exit(1);
}

my $repodir1 = $homedir . '/r1';
remove_tree($repodir1);

my $r1 = Git::Raw::Repository->init($repodir1, 1);

my $branchname = 'DataBranch';
{
    my $builder = Git::Raw::Tree::Builder->new($r1);
    $builder->clear();
    my $tree = $builder->write();
    
    my $me = _signature();
    my $commit = $r1->commit("Initial commit in $branchname" ,
                             $me, $me, [], $tree, undef);
    $r1->branch($branchname, $commit);
}


my $msg_filename = 'x/y/msg.txt';

{
    my $branch = Git::Raw::Branch->lookup($r1, $branchname, 1);
    die("Cannot lookup $branchname") unless defined($branch);
    
    my $index = Git::Raw::Index->new();
    $r1->index($index);

    my $tip_tree = $branch->peel('tree');
    $index->read_tree($tip_tree);
    
    $index->add_frombuffer($msg_filename, "msg 1\n");
    my $tree = $index->write_tree();

    my $me = _signature();
    my $parent = $branch->peel('commit');
    $r1->commit('1', $me, $me, [$parent], $tree, $branch->name());
}

read_data();

{
    my $index = $r1->index();
    $index->add_frombuffer($msg_filename, "msg 2\n");
    read_data();
    $index->write_tree();
    read_data();
}


sub read_data
{
    # must re-read the branch
    my $branch = Git::Raw::Branch->lookup($r1, $branchname, 1);
    my $tree = $branch->peel('tree');
    my $entry = $tree->entry_bypath($msg_filename);
    die("Cannot find $msg_filename in the tree") unless defined($entry);
    print "From tree: ", $entry->object()->content();

    my $index = $r1->index();
    $entry = $index->find($msg_filename);
    print "From index: ", $entry->blob()->content();
}


sub _signature
{
    return Git::Raw::Signature->now('Z', 'x@x.com');
}



