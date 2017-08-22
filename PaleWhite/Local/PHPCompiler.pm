#!/usr/bin/env perl
package PaleWhite::Local::PHPCompiler;
use strict;
use warnings;

use feature 'say';

use Data::Dumper;

use PaleWhite::Local::Parser;



our $model_identifier_regex = qr/\Amodel::[a-zA-Z_][a-zA-Z0-9_]*+(?:::[a-zA-Z_][a-zA-Z0-9_]*+)*\Z/s;


sub new {
	my ($class, %args) = @_;
	my $self = bless {}, $class;

	return $self
}



sub format_classname {
	my ($self, $classname) = @_;
	return "\\$classname" =~ s/::/\\/gr
}

sub compile_localization {
	my ($self, $def) = @_;
	die "invalid localization definition: $def->{type} on line $def->{line_number}"
			unless $def->{type} eq 'localization_definition';

	my $namespace = "Localization\\$def->{localization_identifier}";

	my @prefix_code;
	my @code;

	if (defined $self->{active_namespace}) {
		die "cannot have multiple different namespaces in one localization file, on line $def->{line_number}. ",
				"new namespace '$namespace' while previously defined namespace was '$self->{active_namespace}'"
				unless $self->{active_namespace} eq $namespace;
	} else {
		$self->{active_namespace} = $namespace;
		push @prefix_code, "namespace $namespace;\n\n";
	}

	foreach my $field (@{$def->{fields}}) {
		push @code, $self->compile_data_field($def, $field);
	}
	@code = map "\t$_", @code;
	@code = ("class $def->{identifier} extends \\PaleWhite\\LocalizationDefinition {\n", @code, "}\n\n");

	return @prefix_code, @code
}

sub compile_data_field {
	my ($self, $def, $field) = @_;
	my @code;

	if ($field->{type} eq 'string_field') {
		push @code, "public static \$$field->{identifier} = '$field->{value}';\n";

	} else {
		die "unimplemented data field '$field->{type}' on line $field->{line_number}";
	}

	return @code
}



sub compile_file {
	my ($file) = @_;
	use Sugar::IO::File;

	my $parser = PaleWhite::Local::Parser->new;
	$parser->{filepath} = Sugar::IO::File->new($file);
	my $tree = $parser->parse;
	# say Dumper $tree;

	my $compiler = __PACKAGE__->new;
	my @code = ("<?php\n\n", map $compiler->compile_localization($_), @$tree);
	return join '', @code
}


sub main {
	foreach my $file (@_) {
		say compile_file($file);
	}
}

caller or main(@ARGV);

1;
