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

## Server repo
my $r1 = Git::Raw::Repository->init($dir . '/r1', 1);

## Producer repo
my $r2 = Git::Raw::Repository->init($dir . '/r2', 0);

## Consumer repo
my $r3 = Git::Raw::Repository->init($dir . '/r3', 0);

my $checkout_notify_cb = sub {
    my $file = shift;
    my $why = shift;
    if( defined($file) ) {
        printf("Checkout notify %s: %s\n", $file, join(',', @{$why}));
    }
    return 0;
};

my $checkout_progress_cb = sub {
    my $file = shift;
    my $completed_steps = shift;
    my $total_steps = shift;
    if( defined($file) ) {
        printf("Checkout progress %s: %d out of %d\n", $file,
               $completed_steps, $total_steps);
    }
    return 0;
};


my $checkout_opts = {
    'checkout_strategy' => {'safe' => 1},
    'callbacks' => {'notify' => $checkout_notify_cb,
                    'progress' => $checkout_progress_cb},
    'notify' => ['all']
};

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

    $r3->checkout($branch, $checkout_opts);
    print "OK checkout\n";
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

    my $branch = Git::Raw::Branch->lookup( $r2, 'R2', 1 );
    my $ref = $branch->name();
    my $remote = Git::Raw::Remote->load($r2, $branch->remote_name());
    die('X2') unless defined($remote);
    $remote->push([$ref]);
    print "OK push3\n";
}



## Pull to the consumer
{
    my $start = $r3->head()->peel('tree');
    my $branch = Git::Raw::Branch->lookup($r3, 'R2', 1);
    die("Cannot lookup branch") unless defined($branch);

    my $remote = Git::Raw::Remote->load($r3, $branch->remote_name());
    die('X3') unless defined($remote);

    $remote->fetch();
    print "OK fetch\n";

    my $ref = Git::Raw::Reference->lookup('remotes/origin/R2', $r3 );

    my $end = $ref->peel('tree');

	print "Getting tree diff $start..$end\n";
	my $diff = $start->diff ({tree => $end,
		skip_binary_check => 1,
		enable_fast_untracked_dirs => 1,
	});

	my @patches = $diff->patches();
	foreach my $patch (@patches)
	{
		my $tree = Git::Raw::Tree->lookup ($r3, $end->id());
		my $delta = $patch->delta();
		my $path = $delta->new_file()->path();

		if ($delta->status() ne 'deleted')
		{
			my $blob = $tree->entry_bypath ($path)->object();
			print "[$path] Content: ", $blob->content();
		}
		else
		{
			print "[$path] REMOVED!\n";
		}
	}
}





