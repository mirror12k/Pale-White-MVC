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

	my @includes;

	my $setup_sql_file = Sugar::IO::File->new("$bin_dir/setup.sql");
	my $includes_file = Sugar::IO::File->new("$bin_dir/includes.php");
	# clear the setup.sql file
	$setup_sql_file->write('');

	foreach my $source_path (grep /\.model\Z/, $src_dir->recursive_files) {

		my $relative_path = $source_path =~ s/\A$src_dir\/*//r;
		my $destination_path = $relative_path =~ s/\.model\Z/\.php/r;
		$destination_path = "$bin_dir/$destination_path";
		my $destination_directory = $destination_path =~ s#/[^/]+\Z##r;
		# say "model: $source_path ($relative_path => $destination_path ($destination_directory))";
		say "model: $source_path => $destination_path";

		my $compiled_php = PaleWhite::ModelPHPCompiler::compile_file($source_path);
		Sugar::IO::File->new($destination_path)->write($compiled_php);
		my $compiled_sql = PaleWhite::ModelSQLCompiler::compile_file($source_path);
		$setup_sql_file->append($compiled_sql);

		push @includes, $destination_path;
	}

	foreach my $source_path (grep /\.glass\Z/, $src_dir->recursive_files) {

		my $relative_path = $source_path =~ s/\A$src_dir\/*//r;
		my $destination_path = $relative_path =~ s/\.glass\Z/\.php/r;
		$destination_path = "$bin_dir/$destination_path";
		my $destination_directory = $destination_path =~ s#/[^/]+\Z##r;
		# say "model: $source_path ($relative_path => $destination_path ($destination_directory))";
		say "template: $source_path => $destination_path";

		my $compiled_php = PaleWhite::Glass::PHPCompiler::compile_file($source_path);
		Sugar::IO::File->new($destination_path)->write($compiled_php);
		
		push @includes, $destination_path;
	}

	foreach my $source_path (grep /\.controller\Z/, $src_dir->recursive_files) {

		my $relative_path = $source_path =~ s/\A$src_dir\/*//r;
		my $destination_path = $relative_path =~ s/\.controller\Z/\.php/r;
		$destination_path = "$bin_dir/$destination_path";
		my $destination_directory = $destination_path =~ s#/[^/]+\Z##r;
		# say "model: $source_path ($relative_path => $destination_path ($destination_directory))";
		say "controller: $source_path => $destination_path";

		my $compiled_php = PaleWhite::ControllerPHPCompiler::compile_file($source_path);
		Sugar::IO::File->new($destination_path)->write($compiled_php);
		
		push @includes, $destination_path;
	}

	my $compiled_php = compile_includes(@includes);
	$includes_file->write($compiled_php);
}



sub main {
	use Data::Dumper;

	die "usage: $0 <src directory> <bin directory>" unless @_ == 2;
	compile_project_directory(@_);
}

caller or main(@ARGV);


