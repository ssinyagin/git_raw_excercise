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

my $n_branches = 10;

# Create empty commits for every branch

for(my $i=0; $i < $n_branches; $i++)
{
    my $branchname = sprintf('br%d', $i);

    my $builder = Git::Raw::Tree::Builder->new($r1);
    $builder->clear();
    my $tree = $builder->write();
    
    my $me = _signature();
    my $commit = $r1->commit("Initial commit in $branchname" ,
                             $me, $me, [], $tree, undef);
    # print "Created commit: $commit\n";
    
    my $branch = $r1->branch($branchname, $commit);
    print "Created branch: $branchname\n";   
}

# Get in-memory index for every branch (requires a repo object for each one)


my @repos;

for(my $i=0; $i < $n_branches; $i++)
{
    my $branchname = sprintf('br%d', $i);

    my $repo = Git::Raw::Repository->open($repodir1);

    my $branch = Git::Raw::Branch->lookup($repo, $branchname, 1);
    die("Cannot lookup $branchname") unless defined($branch);
        
    my $index = Git::Raw::Index->new();
    $repo->index($index);
    
    my $tip_tree = $branch->peel('tree');
    $index->read_tree($tip_tree);
    
    push(@repos, $repo);
}

print "initialized indexes\n";   

# write into every index, then make commits

for(my $k=0; $k<3; $k++)
{
    for(my $i=0; $i < $n_branches; $i++)
    {
        my $branchname = sprintf('br%d', $i);
        my $index = $repos[$i]->index();
        my $msg = sprintf("Update No. %d in branch %s\n", $k, $branchname);
        $index->add_frombuffer('msg.txt', $msg);
        # print $msg;
    }

    for(my $i=0; $i < $n_branches; $i++)
    {
        my $branchname = sprintf('br%d', $i);

        my $repo = $repos[$i];
        my $index = $repo->index();

        my $tree = $index->write_tree();
        
        my $branch = Git::Raw::Branch->lookup( $repo, $branchname, 1 );
        die("Cannot lookup $branchname") unless defined($branch);

        my $parent = $branch->peel('commit');
        
        my $me = _signature();
        my $msg = sprintf("Commit No. %d in branch %s\n", $k, $branchname);
        my $commit =
            $repo->commit($msg, $me, $me, [$parent], $tree, $branch->name());
        # print "Created commit: $commit\n";
    }
}

print "created commits\n";

# read the contents

for(my $i=0; $i < $n_branches; $i++)
{
    my $branchname = sprintf('br%d', $i);
    
    my $repo = $repos[$i];
    my $index = $repo->index();
        
    my $branch = Git::Raw::Branch->lookup( $repo, $branchname, 1 );
    die("Cannot lookup $branchname") unless defined($branch);
    
    my $tree = $branch->peel('tree');

    my $entry = $tree->entry_bypath('msg.txt');
    die("Cannot find entry by path") unless defined($entry);

    my $object = $entry->object();
    die("Entry is not a blob") unless $object->is_blob();

    print $object->content();
}



        
    
sub _signature
{
    return Git::Raw::Signature->now('Z', 'x@x.com');
}



