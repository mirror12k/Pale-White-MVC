#!/usr/bin/env perl
package PaleWhite::ModelSQLCompiler;
use strict;
use warnings;

use feature 'say';

use Data::Dumper;

use PaleWhite::ModelParser;



sub compile {
	my ($tree) = @_;

	my $code = "\n";
	$code .= join '', compile_model($_) foreach @$tree;

	return $code
}

sub compile_property {
	my ($property) = @_;

	my $identifier = $property->{identifier};
	my $type;
	my $suffix = '';

	# say Dumper $property;
	if ($property->{property_type} eq 'int') {
		$type = 'INT'
	} elsif ($property->{property_type} eq 'string') {
		$type = 'VARCHAR(256)'
	} else {
		die "undefined property type: $property->{property_type}";
	}

	$suffix .= " NOT NULL auto_increment" if exists $property->{modifiers}{auto_increment};
	$suffix .= ", UNIQUE KEY `$identifier` (`$identifier`)" if exists $property->{modifiers}{unique_key};

	return "$identifier $type$suffix"
}

sub compile_model {
	my ($model) = @_;

	my %model_properties;

	my @code;
	push @code, "CREATE TABLE IF NOT EXISTS $model->{identifier} (\n";
	my @property_code;

	push @property_code, compile_property({
		identifier => 'id',
		property_type => 'int',
		modifiers => {
			auto_increment => 1,
			unique_key => 1,
		},
	});
	$model_properties{id} = 1;

	foreach my $property (@{$model->{properties}}) {
		die "duplicate property $property->{identifier} defined in model $model->{identifier}"
				if exists $model_properties{$property->{identifier}};
		$model_properties{$property->{identifier}} = 1;

		push @property_code, compile_property($property);
	}

	foreach (0 .. $#property_code - 1) {
		$property_code[$_] .= ',';
	}

	push @code, map "\t$_\n", @property_code;

	push @code, ");\n";
	push @code, "\n";
	push @code, "\n";
	push @code, "\n";

	return @code
}





sub main {
	use Data::Dumper;
	use Sugar::IO::File;

	my $parser = PaleWhite::ModelParser->new;
	foreach my $file (@_) {
		$parser->{filepath} = Sugar::IO::File->new($file);
		my $tree = $parser->parse;
		# say Dumper $tree;

		my $text = compile($tree);
		say $text;
	}
}

caller or main(@ARGV);
