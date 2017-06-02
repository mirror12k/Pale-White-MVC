#!/usr/bin/env perl
package PaleWhite::ProjectCompiler;
use strict;
use warnings;

use feature 'say';

use Data::Dumper;

use Sugar::IO::File;
use Sugar::IO::Dir;

use PaleWhite::ControllerPHPCompiler;
use PaleWhite::Glass::PHPCompiler;
use PaleWhite::ModelPHPCompiler;
use PaleWhite::ModelSQLCompiler;




sub compile_includes {
	my (@includes) = @_;

	my @code;

	push @code, "<?php\n";
	push @code, "\n";
	push @code, "\n";

	push @code, "require_once '$_';\n" foreach @includes;
	push @code, "\n";
	push @code, "\n";

	return join '', @code
}

sub compile_project_directory {
	my ($src_dir, $bin_dir) = @_;
	$src_dir = Sugar::IO::Dir->new($src_dir);
	$bin_dir = Sugar::IO::Dir->new($bin_dir);

	say "compiling PaleWhite project: $src_dir => $bin_dir";

	my @includes;

	my $setup_sql_file = Sugar::IO::File->new("$bin_dir/setup.sql");
	my $includes_file = Sugar::IO::File->new("$bin_dir/includes.php");
	my $config_file = Sugar::IO::File->new("$bin_dir/config.php");
	my $index_file = Sugar::IO::File->new("$bin_dir/index.php");

	# clear the setup.sql file
	$setup_sql_file->write('');
	# add in PaleWhite library as an include
	push @includes, "phplib/PaleWhite/lib.php";

	foreach my $source_path (grep /\.model\Z/, $src_dir->recursive_files) {

		my $relative_path = $source_path =~ s/\A$src_dir\/*//r;
		$relative_path =~ s/\.model\Z/\.php/;
		my $destination_path = "$bin_dir/$relative_path";
		my $destination_directory = $destination_path =~ s#/[^/]+\Z##r;
		# say "model: $source_path ($relative_path => $destination_path ($destination_directory))";
		say "\tmodel: $source_path => $destination_path";

		my $compiled_php = PaleWhite::ModelPHPCompiler::compile_file($source_path);
		Sugar::IO::File->new($destination_path)->write($compiled_php);
		my $compiled_sql = PaleWhite::ModelSQLCompiler::compile_file($source_path);
		$setup_sql_file->append($compiled_sql);

		push @includes, $relative_path;
	}
	say "\tsetup.sql file: $setup_sql_file";

	foreach my $source_path (grep /\.glass\Z/, $src_dir->recursive_files) {

		my $relative_path = $source_path =~ s/\A$src_dir\/*//r;
		$relative_path =~ s/\.glass\Z/\.php/;
		my $destination_path = "$bin_dir/$relative_path";
		my $destination_directory = $destination_path =~ s#/[^/]+\Z##r;
		# say "\tmodel: $source_path ($relative_path => $destination_path ($destination_directory))";
		say "\ttemplate: $source_path => $destination_path";

		my $compiled_php = PaleWhite::Glass::PHPCompiler::compile_file($source_path);
		Sugar::IO::File->new($destination_path)->write($compiled_php);
		
		push @includes, $relative_path;
	}

	foreach my $source_path (grep /\.controller\Z/, $src_dir->recursive_files) {

		my $relative_path = $source_path =~ s/\A$src_dir\/*//r;
		$relative_path =~ s/\.controller\Z/\.php/;
		my $destination_path = "$bin_dir/$relative_path";
		my $destination_directory = $destination_path =~ s#/[^/]+\Z##r;
		# say "\tmodel: $source_path ($relative_path => $destination_path ($destination_directory))";
		say "\tcontroller: $source_path => $destination_path";

		my $compiled_php = PaleWhite::ControllerPHPCompiler::compile_file($source_path);
		Sugar::IO::File->new($destination_path)->write($compiled_php);
		
		push @includes, $relative_path;
	}

	my $compiled_php = compile_includes(@includes);
	say "\tincludes file: $includes_file";
	$includes_file->write($compiled_php);

	unless ($config_file->exists) {
		say "\tconfig file: $config_file";

		$config_file->write("<?php

global \$config;

\$config = array(
	'site_base' => '',
	'main_controller' => 'MainController',
	'database_config' => array(
		'mysql_host' => 'localhost',
		'mysql_username' => 'root',
		'mysql_password' => '',
		'mysql_database' => '',
	),
);

");
	}

	unless ($index_file->exists) {
		say "\tindex file: $index_file";
		$index_file->write("<?php

require_once 'includes.php';
require_once 'config.php';

\$executor = new \\PaleWhite\\HTTPRequestExecutor();
\$executor->execute();

");
	}

}



sub main {
	use Data::Dumper;

	die "usage: $0 <src directory> <bin directory>" unless @_ == 2;
	compile_project_directory(@_);
}

caller or main(@ARGV);


