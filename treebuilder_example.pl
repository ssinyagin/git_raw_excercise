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

my $builder = Git::Raw::Tree::Builder->new($r1);

my $blob = $r1->blob("Hello world\n");

my $entry = $builder->insert('hello_world.txt', $blob, 0100644);

my $tree = $builder->write();

my $me = _signature();
$r1->commit('Hello World commit', $me, $me, [], $tree);

my $branch = Git::Raw::Branch->lookup( $r1, 'master', 1 );
$branch->move('DataTree', 1);



sub_add_commit
{
    my $data = shift; # hash filename->content
    my $msg = shift;  # commit message

    foreach my $fname (sort keys %{$data})
    {
        my @path_elements = split('/', $fname);

        # need some recursive majic here
        
    }
}











sub _signature
{
    return Git::Raw::Signature->now('Z', 'x@x.com');
}



