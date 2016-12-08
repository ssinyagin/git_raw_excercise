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
my $index = $r1->index();

# Initial
$index->add_frombuffer('hello_world.txt', "Hello world\n");
my $tree = $index->write_tree();
print "Created initial tree: $tree\n";

my $me = _signature();
my $commit1 = $r1->commit('Hello World commit', $me, $me, [], $tree);
print "Created commit1: $commit1\n";

my $branch = Git::Raw::Branch->lookup( $r1, 'master', 1 );
$branch->move('DataTree', 1);

#Optional (needed if the commit has changed)
$index->read_tree ($commit1->tree());

$index->add_frombuffer('c.txt', 'somecontents2');
$index->add_frombuffer('b/c.txt', 'somecontents2');
$index->add_frombuffer('a/b/c.txt', 'somecontents2');
$index->add_frombuffer('b.txt', 'somecontents1');
$index->add_frombuffer('c.txt', 'somecontents2');
$index->add_frombuffer('a.txt', 'somecontents3');
$index->add_frombuffer('d.txt', 'somecontents4');

$tree = $index->write_tree();

print "Created new tree: $tree\n";
my $commit2 = $r1->commit('Hello World commit', $me, $me, [$commit1], $tree);
print "Created commit2: $commit2\n";

print "Listing: git ls-tree -r $tree\n";
system ("cd $repodir1; git ls-tree -r $tree");

sub _signature
{
    return Git::Raw::Signature->now('Z', 'x@x.com');
}



