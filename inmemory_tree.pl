use strict;
use warnings;

use Git::Raw;
use Git::Raw::Tree;
use Git::Raw::Tree::Entry;
use IO::File;
use Data::Dumper;
use File::Spec::Functions qw(catfile);
use File::Path qw(make_path remove_tree);
use File::Slurp::Tiny qw(read_file);


my $dir = '/tmp/gittest';
if( -d $dir )
{
    remove_tree($dir);
}

## Producer repo
my $r2 = Git::Raw::Repository->init($dir . '/r2', 0);

## Init the producer
{
    my $index = $r2->index;
    $index->write;
    my $tree = $index->write_tree;

    my $me = Git::Raw::Signature->now('Z', 'x@x.com');

    $r2->commit('First empty commit', $me, $me, [], $tree);

    my $branch = Git::Raw::Branch->lookup( $r2, 'master', 1 );
    $branch->move('R2', 1);

    $branch = Git::Raw::Branch->lookup( $r2, 'R2', 1 );
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

## Update the producer and push to server
{
    my $fh = IO::File->new($dir . '/r2/yy', 'w');
    $fh->print("blahblah\n");
    $fh->close;

    $fh = IO::File->new($dir . '/r2/yy2', 'w');
    $fh->print("blahblah2\n");
    $fh->close;

    unlink $dir . '/r2/xx';

    my $index = $r2->index;
    $index->add ('yy');
    $index->add ('yy2');
    $index->remove ('xx');
    $index->write;
    my $tree = $index->write_tree();
    my $me = Git::Raw::Signature->now('Z', 'x@x.com');
    my $head = $r2->head->target;
    $r2->commit('Third commit', $me, $me, [$head], $tree);
    print "OK commit3\n";
}

## All files in the tree (initial state)
{
	print "All files in tree\n";
    my $branch = Git::Raw::Branch->lookup( $r2, 'R2', 1 );
    my $tree = $branch->peel('tree');
	foreach my $entry ($tree->entries())
	{
		my $path = $entry->name();
		my $blob = $entry->object();
		print "[$path] Content: ", $blob->content();
	}
}
