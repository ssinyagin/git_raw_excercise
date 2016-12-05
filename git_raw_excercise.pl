use strict;
use warnings;

use Git::Raw;
use IO::File;
use Data::Dumper;
use File::Path qw(make_path remove_tree);


my $dir = '/tmp/gittest';
if( -d $dir )
{
    remove_tree($dir);
}

## Server repo
my $r1 = Git::Raw::Repository->init($dir . '/r1', 1);

## Producer repo
my $r2 = Git::Raw::Repository->init($dir . '/r2', 0);

## Consumer repo
my $r3 = Git::Raw::Repository->init($dir . '/r3', 0);


## Init the producer
{
    my $remote =
        Git::Raw::Remote->create($r2, 'origin', 'file://' . $dir . '/r1');

    my $index = $r2->index;
    $index->write;
    my $tree = $index->write_tree;

    my $me = Git::Raw::Signature->now('Z', 'x@x.com');

    $r2->commit('First empty commit', $me, $me, [], $tree);

    my $branch = Git::Raw::Branch->lookup( $r2, 'master', 1 );
    $branch->move('R2', 1);

    $remote->push(['refs/heads/R2']);
    print "OK push\n";

    $branch = Git::Raw::Branch->lookup( $r2, 'R2', 1 );
    my $ref = Git::Raw::Reference->lookup('refs/remotes/origin/R2', $r2);
    $branch->upstream($ref);
    print "OK upstr\n";
}

## Update the producer
{
    my $fh = IO::File->new($dir . '/r2/xx', 'w');
    $fh->print("blahblah\n");
    $fh->close;
    
    my $index = $r2->index;
    $index->add ('xx');
    $index->write;
    my $tree = $index->write_tree();
    my $me = Git::Raw::Signature->now('Z', 'x@x.com');
    my $head = $r2->head->target;
    $r2->commit('Second commit', $me, $me, [$head], $tree);
    print "OK commit2\n";
}

## Push to the server
{
    my $branch = Git::Raw::Branch->lookup( $r2, 'R2', 1 );
    my $ref = $branch->name();
    my $remote_name = $branch->remote_name();
    my $remote = Git::Raw::Remote->load($r2, $remote_name);
    die('X1') unless defined($remote);
    $remote->push([$ref]);
    print "OK push2\n";
}

## Init the consumer
{
    # Default refspec is to fetch all branches.
    # We change it to fetch a specific branch.
    
    my $config = $r3->config();
    $config->str('remote.origin.url', 'file://' . $dir . '/r1');
    $config->str('remote.origin.fetch',
                 '+refs/heads/R2:refs/remotes/origin/R2');
    
    $config->str('branch.R2.remote', 'origin');
    $config->str('branch.R2.merge', 'refs/heads/R2');
    
    my $remote = Git::Raw::Remote->load($r3, 'origin');
    $remote->fetch();
    print "OK fetch\n";

    my $ref = Git::Raw::Reference->lookup('remotes/origin/R2', $r3);
    die('REF') unless defined($ref);
    print "OK ref\n";
    
    my $branch = $r3->branch('R2', $ref->target);
    print "OK branch\n";

    $r3->head($branch);
    print "OK head\n";
    
    $r3->checkout($branch, {'checkout_strategy' => {'safe' => 1}});
    print "OK checkout\n";
}


## Update the producer and push to server
{
    my $fh = IO::File->new($dir . '/r2/yy', 'w');
    $fh->print("blahblah\n");
    $fh->close;
    
    my $index = $r2->index;
    $index->add ('yy');
    $index->write;
    my $tree = $index->write_tree();
    my $me = Git::Raw::Signature->now('Z', 'x@x.com');
    my $head = $r2->head->target;
    $r2->commit('Third commit', $me, $me, [$head], $tree);
    print "OK commit3\n";

    my $branch = Git::Raw::Branch->lookup( $r2, 'R2', 1 );
    my $ref = $branch->name();
    my $remote = Git::Raw::Remote->load($r2, $branch->remote_name());
    die('X2') unless defined($remote);
    $remote->push([$ref]);
    print "OK push3\n";
}
    

## Pull to the consumer
{
    print "Current HEAD: ", $r3->head()->name(), " ", $r3->head()->peel ('commit')->id, "\n";
    my $branch = Git::Raw::Branch->lookup($r3, 'R2', 1);    
    die("Cannot lookup branch") unless defined($branch);
    
    my $remote = Git::Raw::Remote->load($r3, $branch->remote_name());
    die('X3') unless defined($remote);
    
    $remote->fetch();
    print "OK fetch\n";

    my $ref = Git::Raw::Reference->lookup('remotes/origin/R2', $r3 );
    die('REF3') unless defined($ref);

    my $analysis = $r3->merge_analysis($ref);
    die("Only supports fast-forward merges at this time") if (!grep {$_ eq 'fast_forward'} @$analysis);

    my $commit = $ref->peel('commit');
    my $tree = $commit->tree();
    my $index = $r3->index();
    $index->read_tree($tree);
    $index->write();

    $r3->checkout($tree, {'checkout_strategy' => {'force' => 1}});
    $r3->head($branch->target($commit));

    print "Detached: ", $r3->is_head_detached(), "\n";
    print "Final HEAD: ", $r3->head()->name(), " ", $r3->head()->peel ('commit')->id, "\n";
    
    print "OK checkout\n";
}





