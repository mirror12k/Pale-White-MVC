#!/usr/bin/env perl
package PaleWhite::MVC::ModelSQLCompiler;
use strict;
use warnings;

use feature 'say';

use Data::Dumper;



# sub compile {
# 	my ($tree) = @_;

# 	my $code = "\n";
# 	$code .= join '', compile_model($_) foreach @$tree;

# 	return $code
# }

sub compile_property {
	my ($property) = @_;

	my $identifier = $property->{identifier};
	my $type;
	my $suffix = '';

	# say Dumper $property;
	if ($property->{type} eq 'model_pointer_property' or $property->{property_type} eq 'int') {
		warn "superfluous property size in int property" if exists $property->{modifiers}{property_size};
		$type = 'INT';
	} elsif ($property->{type} eq 'file_pointer_property') {
		warn "superfluous property size in file pointer property" if exists $property->{modifiers}{property_size};
		$type = 'VARCHAR(256)';
	} elsif ($property->{property_type} eq 'json') {
		$type = 'TEXT';
	} elsif ($property->{property_type} eq 'salted_sha256') {
		$type = 'VARCHAR(256)';
	} elsif ($property->{property_type} eq 'string') {
		if (exists $property->{modifiers}{property_size}) {
			$type = "VARCHAR($property->{modifiers}{property_size})";
		} else {
			$type = 'TEXT';
		}
	} else {
		die "undefined property type: $property->{property_type}";
	}

	$suffix .= " DEFAULT $property->{modifiers}{default}" if exists $property->{modifiers}{default};
	$suffix .= " NOT NULL auto_increment" if exists $property->{modifiers}{auto_increment};
	$suffix .= ", UNIQUE (`$identifier`)" if exists $property->{modifiers}{unique};
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
		type => 'implicit_model_property',
		identifier => 'id',
		property_type => 'int',
		modifiers => {
			auto_increment => 1,
			unique_key => 1,
		},
	});
	$model_properties{id} = 1;

	foreach my $property (
			grep { not exists $_->{modifiers}{array_property} and not exists $_->{modifiers}{map_property} }
			@{$model->{properties}}) {
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

	foreach my $property (grep { exists $_->{modifiers}{array_property} } @{$model->{properties}}) {
		die "duplicate property $property->{identifier} defined in model $model->{identifier}"
				if exists $model_properties{$property->{identifier}};
		$model_properties{$property->{identifier}} = 1;

		push @code, compile_array_property($model, $property);
	}

	foreach my $property (grep { exists $_->{modifiers}{map_property} } @{$model->{properties}}) {
		die "duplicate property $property->{identifier} defined in model $model->{identifier}"
				if exists $model_properties{$property->{identifier}};
		$model_properties{$property->{identifier}} = 1;

		push @code, compile_map_property($model, $property);
	}

	return @code
}

sub compile_array_property {
	my ($model, $property) = @_;

	my @code;
	push @code, "CREATE TABLE IF NOT EXISTS $model->{identifier}__array_property__$property->{identifier} (\n";
	my @property_code;

	push @property_code, compile_property({
		type => 'implicit_model_property',
		identifier => 'id',
		property_type => 'int',
		modifiers => {
			auto_increment => 1,
			unique_key => 1,
		},
	});
	push @property_code, compile_property({
		type => 'implicit_model_property',
		identifier => 'parent_id',
		property_type => 'int',
	});

	# clone the property to set the identifier to 'value'
	push @property_code, compile_property({ %$property, identifier => 'value' });

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

sub compile_map_property {
	my ($model, $property) = @_;

	my @code;
	push @code, "CREATE TABLE IF NOT EXISTS $model->{identifier}__map_property__$property->{identifier} (\n";
	my @property_code;

	push @property_code, compile_property({
		type => 'implicit_model_property',
		identifier => 'id',
		property_type => 'int',
		modifiers => {
			auto_increment => 1,
			unique_key => 1,
		},
	});
	push @property_code, compile_property({
		type => 'implicit_model_property',
		identifier => 'parent_id',
		property_type => 'int',
	});
	push @property_code, compile_property($property->{modifiers}{map_property});

	# clone the property to set the identifier to 'value'
	push @property_code, compile_property({ %$property, identifier => 'value' });

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



# sub compile_file {
# 	my ($file) = @_;
# 	use Sugar::IO::File;
# 	use PaleWhite::ModelParser;

# 	my $parser = PaleWhite::ModelParser->new;
# 	$parser->{filepath} = Sugar::IO::File->new($file);
# 	my $tree = $parser->parse;
# 	# say Dumper $tree;

# 	my $text = compile($tree);
# 	return $text;
# }



# sub main {
# 	foreach my $file (@_) {
# 		say compile_file($file);
# 	}
# }

# caller or main(@ARGV);

1;
