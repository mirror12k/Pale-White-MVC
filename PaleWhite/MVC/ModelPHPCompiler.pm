#!/usr/bin/env perl
package PaleWhite::MVC::ModelPHPCompiler;
use strict;
use warnings;

use feature 'say';

use Data::Dumper;



# sub compile {
# 	my ($tree) = @_;

# 	my $code = "<?php\n\n\n";
# 	$code .= join '', compile_model($_) foreach @$tree;

# 	return $code
# }


sub compile_model {
	my ($model) = @_;


	my @code;

	push @code, "public static \$table_name = '$model->{identifier}';\n\n";
	push @code, "public static \$_model_cache = array('id' => array());\n";

	my @model_properties = grep { not exists $_->{modifiers}{array_property} } @{$model->{properties}};
	my @model_array_properties = grep { exists $_->{modifiers}{array_property} } @{$model->{properties}};
	my @model_submodel_properties = grep { $_->{type} eq 'model_pointer_property' } @{$model->{properties}};
	my @model_file_properties = grep { $_->{type} eq 'file_pointer_property' } @{$model->{properties}};
	my @model_json_properties = grep { $_->{type} eq 'model_property' and $_->{property_type} eq 'json' } @{$model->{properties}};

	if (@model_properties) {
		push @code, "public static \$model_properties = array(\n";
		push @code, "\t'id' => 'int',\n";
		push @code, "\t'$_->{identifier}' => '$_->{property_type}',\n" foreach @model_properties;
		push @code, ");\n";
	} else {
		push @code, "public static \$model_properties = array();\n";
	}

	if (@model_array_properties) {
		push @code, "public static \$model_array_properties = array(\n";
		push @code, "\t'$_->{identifier}' => '$_->{property_type}',\n" foreach @model_array_properties;
		push @code, ");\n";
	} else {
		push @code, "public static \$model_array_properties = array();\n";
	}

	if (@model_submodel_properties) {
		push @code, "public static \$model_submodel_properties = array(\n";
		push @code, "\t'$_->{identifier}' => '$_->{property_type}',\n" foreach @model_submodel_properties;
		push @code, ");\n";
	} else {
		push @code, "public static \$model_submodel_properties = array();\n";
	}

	if (@model_file_properties) {
		push @code, "public static \$model_file_properties = array(\n";
		push @code, "\t'$_->{identifier}' => '$_->{property_type}',\n" foreach @model_file_properties;
		push @code, ");\n";
	} else {
		push @code, "public static \$model_file_properties = array();\n";
	}

	if (@model_json_properties) {
		push @code, "public static \$model_json_properties = array(\n";
		push @code, "\t'$_->{identifier}' => '$_->{property_type}',\n" foreach @model_json_properties;
		push @code, ");\n";
	} else {
		push @code, "public static \$model_json_properties = array();\n";
	}

	push @code, "\n";
	my %model_functions;
	foreach my $function (@{$model->{functions}}) {
		die "duplicate function $function->{identifier} defined in model $model->{identifier}"
				if exists $model_functions{$function->{identifier}};
		$model_functions{$function->{identifier}} = 1;

		if ($function->{type} eq 'model_function') {
			push @code, "public function $function->{identifier} () {\n";
			push @code, map "$_\n", split "\n", $function->{code};
			push @code, "}\n";
		} elsif ($function->{type} eq 'model_static_function') {
			push @code, "public static function $function->{identifier} () {\n";
			push @code, map "$_\n", split "\n", $function->{code};
			push @code, "}\n";
		} elsif ($function->{type} eq 'on_event_function') {
			push @code, "public function $function->{identifier} () {\n";
			push @code, "\tparent::$function->{identifier}();\n";
			push @code, map "$_\n", split "\n", $function->{code};
			push @code, "}\n";
		} else {
			die "unimplemented function type $function->{type}";
		}
	}
	push @code, "\n";




	@code = ("class $model->{identifier} extends \\PaleWhite\\Model {\n", @code, "}\n\n\n");

	return @code
}



1;


