#!/usr/bin/env perl
package PaleWhite::MVC::FileDirectoryPHPCompiler;
use strict;
use warnings;

use feature 'say';

use Data::Dumper;



sub new {
	my ($class, %args) = @_;
	my $self = bless {}, $class;

	return $self
}

sub compile_file_directory {
	my ($self, $definition) = @_;
	die "invalid controller: $definition->{type}" unless $definition->{type} eq 'file_directory_definition';

	my @code;

	push @code, "public static \$directory = '$definition->{directory}';\n\n";

	push @code, "public static \$properties = array(\n";
	if (exists $definition->{properties}{suffix_timestamp} and $definition->{properties}{suffix_timestamp}) {
		push @code, "\t'suffix_timestamp' => true,\n";
	} else {
		push @code, "\t'suffix_timestamp' => false,\n";
	}
	push @code, ");\n";
	
	@code = map "\t$_", @code;
	@code = ("class $definition->{identifier} extends \\PaleWhite\\FileDirectory {\n", @code, "}\n", "\n");

	return @code
}

1;
