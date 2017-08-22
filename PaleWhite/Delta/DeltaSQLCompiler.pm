#!/usr/bin/env perl
package PaleWhite::Delta::DeltaSQLCompiler;
use strict;
use warnings;

use feature 'say';

use Data::Dumper;

use PaleWhite::Delta::Parser;
use PaleWhite::MVC::ModelSQLCompiler;



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

sub compile_modeldelta {
	my ($self, $delta) = @_;
	die "invalid modeldelta: $delta->{type}" unless $delta->{type} eq 'modeldelta_definition';

	my @code;

	foreach my $action (@{$delta->{actions}}) {
		push @code, $self->compile_modeldelta_action($delta, $action);
		push @code, "\n";
	}
	# @code = map "\t$_", @code;
	# @code = ("class $identifier extends $parent {\n", @code, "}\n", "\n");

	return @code
}

sub compile_modeldelta_action {
	my ($self, $modeldelta, $action) = @_;
	my @code;

	my $table = $modeldelta->{identifier};

	if ($action->{type} eq 'delete_field') {
		if (exists $action->{property}{modifiers}{array_property}) {
			push @code, "DROP TABLE ${table}__array_property__$action->{property}{identifier};\n";
		} else {
			push @code, "ALTER TABLE $table DROP COLUMN $action->{property}{identifier};\n";
		}

	} elsif ($action->{type} eq 'add_field') {
		if (exists $action->{property}{modifiers}{array_property}) {
			# die "adding array properties is unimplemented";
			push @code, PaleWhite::MVC::ModelSQLCompiler::compile_array_property($modeldelta, $action->{property});

			if (exists $action->{copy_column}) {
				push @code, "INSERT ${table}__array_property__$action->{property}{identifier} SELECT * FROM"
						. " ${table}__array_property__$action->{copy_column};\n";
			}
		} else {
			my $compiled_property = PaleWhite::MVC::ModelSQLCompiler::compile_property($action->{property});
			push @code, "ALTER TABLE $table ADD COLUMN $compiled_property;\n";

			if (exists $action->{copy_column}) {
				push @code, "UPDATE $table SET $action->{property}{identifier} = $action->{copy_column};\n";
			}
		}
		

	} elsif ($action->{type} eq 'modify_field') {
		if (exists $action->{old_property}{modifiers}{array_property}) {

			if ($action->{old_property}{identifier} ne $action->{new_property}{identifier}) {
				push @code, "ALTER TABLE ${table}__array_property__$action->{old_property}{identifier}"
						. " RENAME TO ${table}__array_property__$action->{new_property}{identifier};\n";
			}

			my $compiled_property = PaleWhite::MVC::ModelSQLCompiler::compile_property(
					{ %{$action->{new_property}}, identifier => 'value' });
			push @code, "ALTER TABLE ${table}__array_property__$action->{new_property}{identifier}"
					. " CHANGE COLUMN value $compiled_property;\n";

		} else {
			my $compiled_property = PaleWhite::MVC::ModelSQLCompiler::compile_property($action->{new_property});
			push @code, "ALTER TABLE $table CHANGE COLUMN $action->{old_property}{identifier} $compiled_property;\n";
		}

	} else {
		die "unimplemented modeldelta action '$action->{type}' on line $action->{line_number}";
	}

	return @code
}

# sub compile_property {
# 	my ($self, $property) = @_;

# 	my $identifier = $property->{identifier};
# 	my $type;
# 	my $suffix = '';

# 	# say Dumper $property;
# 	if ($property->{type} eq 'model_pointer_property' or $property->{property_type} eq 'int') {
# 		warn "superfluous property size in int property" if exists $property->{modifiers}{property_size};
# 		$type = 'INT';
# 	} elsif ($property->{type} eq 'file_pointer_property') {
# 		warn "superfluous property size in file pointer property" if exists $property->{modifiers}{property_size};
# 		$type = 'VARCHAR(256)';
# 	} elsif ($property->{property_type} eq 'string') {
# 		if (exists $property->{modifiers}{property_size}) {
# 			$type = "VARCHAR($property->{modifiers}{property_size})";
# 		} else {
# 			$type = "TEXT";
# 		}
# 	} else {
# 		die "undefined property type: $property->{property_type}";
# 	}

# 	$suffix .= " DEFAULT $property->{modifiers}{default}" if exists $property->{modifiers}{default};
# 	$suffix .= " NOT NULL auto_increment" if exists $property->{modifiers}{auto_increment};
# 	$suffix .= ", UNIQUE (`$identifier`)" if exists $property->{modifiers}{unique};
# 	$suffix .= ", UNIQUE KEY `$identifier` (`$identifier`)" if exists $property->{modifiers}{unique_key};

# 	return "$identifier $type$suffix"
# }



sub compile_file {
	my ($file) = @_;
	use Sugar::IO::File;

	my $parser = PaleWhite::Delta::Parser->new;
	$parser->{filepath} = Sugar::IO::File->new($file);
	my $tree = $parser->parse;
	# say Dumper $tree;

	my $compiler = __PACKAGE__->new;
	my @code = map $compiler->compile_modeldelta($_), @$tree;
	return join '', @code
}


sub main {
	foreach my $file (@_) {
		say compile_file($file);
	}
}

caller or main(@ARGV);

1;
