use strict;
use warnings;

require 't/test_helpers.inc.pl';

use Test::NoWarnings;
use Test::More tests => 45;
use Test::Deep;

BEGIN { use_ok('Storage::Handler::AmazonS3'); }
BEGIN { use_ok('Net::Amazon::S3'); }

# Connection configuration
my $config = configuration_from_env();

# Create temporary bucket for unit tests
my $test_bucket_name = 'gridfs-to-s3.testing.' . random_string(32);
say STDERR "Creating temporary bucket '$test_bucket_name'...";
my $native_s3 = Net::Amazon::S3->new(
	{	aws_access_key_id     => $config->{amazon_s3}->{access_key_id},
		aws_secret_access_key => $config->{amazon_s3}->{secret_access_key},
		retry                 => 1,
	}
);
my $test_bucket = $native_s3->add_bucket( { bucket => $test_bucket_name } )
	or die $native_s3->err . ": " . $native_s3->errstr;

# Instances with / without folder name
my $s3_with_folder = Storage::Handler::AmazonS3->new(
    access_key_id => $config->{amazon_s3}->{access_key_id},
    secret_access_key => $config->{amazon_s3}->{secret_access_key},
    bucket_name => $test_bucket_name,
    folder_name => 'files_from_gridfs'
);
my $s3_without_folder = Storage::Handler::AmazonS3->new(
    access_key_id => $config->{amazon_s3}->{access_key_id},
    secret_access_key => $config->{amazon_s3}->{secret_access_key},
    bucket_name => $test_bucket_name,
    folder_name => ''
);


sub run_tests($$)
{
	my ($s3, $description) = @_;

	my $test_filename = 'xyz';
	my $test_content;
	my $returned_content;

	# Store, fetch content
	$test_content     = 'Loren ipsum dolor sit amet.';
	ok( $s3->put( $test_filename, $test_content ), "Storing filename '$test_filename' did not return true ($description)" );
	ok( $s3->head($test_filename), "head() does not report that the file exists");
	ok( $returned_content = $s3->get($test_filename), "Getting filename '$test_filename' did not return contents ($description)" );
	is( $test_content, $returned_content, "Content doesn't match" );
	ok( $s3->delete($test_filename), "Deleting filename '$test_filename' did not return true ($description)" );
	ok( ! $s3->head($test_filename), "head() reports that the file that was just removed still exists");

	# Store content twice
	$test_content     = 'Loren ipsum dolor sit amet.';
	ok( $s3->put( $test_filename, $test_content ), "Storing filename '$test_filename' did not return true ($description)" );
	ok( $s3->put( $test_filename, $test_content ), "Storing filename '$test_filename' the second time did not return true ($description)" );
	ok( $s3->head($test_filename), "head() does not report that the file exists");
	ok( $returned_content = $s3->get($test_filename), "Getting filename '$test_filename' did not return contents ($description)" );
	is( $test_content, $returned_content, "Content doesn't match" );
	ok( $s3->delete($test_filename), "Deleting filename '$test_filename' did not return true ($description)" );
	ok( ! $s3->head($test_filename), "head() reports that the file that was just removed still exists");

	# Store, fetch empty file
	$test_content = '';
	ok( $s3->put( $test_filename, $test_content ), "Storing filename '$test_filename' without contents did not return true ($description)" );
	ok( $s3->head($test_filename), "head() does not report that the file exists");
	$returned_content = $s3->get($test_filename);
	ok( defined($returned_content), "Getting filename '$test_filename' did not return contents ($description)" );
	is( $test_content, $returned_content, "Content doesn't match" );
	ok( $s3->delete($test_filename), "Deleting filename '$test_filename' did not return true ($description)" );
	ok( ! $s3->head($test_filename), "head() reports that the file that was just removed still exists");

	# Try fetching nonexistent filename
	eval { $s3->get('does-not-exist'); };
	ok( $@, "Fetching file that does not exist should have failed" );
	ok( ! $s3->head($test_filename), "head() does not report that the nonexistent file exists");

}

# Run tests for both buckets
run_tests($s3_with_folder, 'with folder');
run_tests($s3_without_folder, 'without folder');

# Delete temporary bucket
$test_bucket->delete_bucket or die $native_s3->err . ": " . $native_s3->errstr;
