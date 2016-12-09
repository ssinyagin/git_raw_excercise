Git as a database back-end
==========================

This is a set of Perl scripts that demonstrate various usage scenarios
of Git::Raw module. Their main purpose is a proof of concept for Torrus
software version 3. The new Torrus will use Git as a back-end for its
configuration database, taking advantage of incremental updates and
network transport.


Bulk test with two working directories, fetch and checkout
----------------------------------------------------------

```
perl bulk_perf_2wd.pl /var/local/gittests 10000
```

This script creates two non-bare Git repositories, writes the specified
number of small JSON files, adds them to the Git, and produces
commits. It then generates emoty commits, then adds more files, and
deletes some files. After every commit, the second repository fetches
the updates checks them out, and the script reads the checked out JSON
files into memory.

As you may see in the output, there are some operations that take up
significant time: the file from the working directory is written to a
blob, then added to the index, then index writes a new tree. Then,
creating a commit is a fast operation. Then, fetching is a relatively
long operation, and then it's followed by checkout which unpacks the
blobs into data files and writes them to the disk.


Bulk test with direct operations on a bare repository
-----------------------------------------------------

```
perl bulk_perf_bare_direct.pl /var/local/gittests 10000
```

This script performs the same job as the previous one, but about 3 times
faster. Instead of working with data files in the filesystem, it writes
new files directly into the Git object storage as blobs, and then
creates the commits from them. Then the reader reads the updates
directly from the Git repository, thus saving on unneccesary disk
operations.

Also, overwriting the data files with the same content is much faster in
this scenario, because Git calculates the SHA-1 checksum on the data
file, and avoids extra disk I/O if the blob is already present.


Example with 3 repositories
---------------------------

```
perl example_3repos.pl
```

The script creates 3 repositories in `/tmp/gittest` and demonstrates
standard client-server operations: the files are created in one
repository, pushed to another, and then the third one fetches the
updates and checks them out.


Example writing into a bare repository
--------------------------------------

```
perl example_bare_repo_write.pl /var/local/gittests
```

This script is a simle example of writing files into a bare Git
repository, exactly like `bulk_perf_bare_direct.pl` is doing.



AUTHORS
-------

Stanislav Sinyagin <ssinyagin@k-open.com>

Jacques Germishuys <jacquesg@cpan.org>


