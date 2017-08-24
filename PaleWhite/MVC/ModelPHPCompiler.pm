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
	push @code, "class $model->{identifier} extends \\PaleWhite\\Model {\n";
	push @code, "\tpublic static \$table_name = '$model->{identifier}';\n";

	push @code, "\tpublic static \$_model_cache = array('id' => array());\n";
	# push @code, "\t\t'id' => array(),\n";
	# foreach my $property (@{$model->{properties}}) {
	# 	push @code, "\t\t'$property->{identifier}' => array(),\n";
	# }
	# push @code, "\t);\n";

	my @model_properties = grep { not exists $_->{modifiers}{array_property} } @{$model->{properties}};
	my @model_array_properties = grep { exists $_->{modifiers}{array_property} } @{$model->{properties}};
	my @model_submodel_properties = grep { $_->{type} eq 'model_pointer_property' } @{$model->{properties}};
	my @model_file_properties = grep { $_->{type} eq 'file_pointer_property' } @{$model->{properties}};
	my @model_json_properties = grep { $_->{type} eq 'model_property' and $_->{property_type} eq 'json' } @{$model->{properties}};

	if (@model_properties) {
		push @code, "\tpublic static \$model_properties = array(\n";
		push @code, "\t\t'id' => 'int',\n";
		push @code, "\t\t'$_->{identifier}' => '$_->{property_type}',\n" foreach @model_properties;
		push @code, "\t);\n";
	} else {
		push @code, "\tpublic static \$model_properties = array();\n";
	}

	if (@model_array_properties) {
		push @code, "\tpublic static \$model_array_properties = array(\n";
		push @code, "\t\t'$_->{identifier}' => '$_->{property_type}',\n" foreach @model_array_properties;
		push @code, "\t);\n";
	} else {
		push @code, "\tpublic static \$model_array_properties = array();\n";
	}

	if (@model_submodel_properties) {
		push @code, "\tpublic static \$model_submodel_properties = array(\n";
		push @code, "\t\t'$_->{identifier}' => '$_->{property_type}',\n" foreach @model_submodel_properties;
		push @code, "\t);\n";
	} else {
		push @code, "\tpublic static \$model_submodel_properties = array();\n";
	}

	if (@model_file_properties) {
		push @code, "\tpublic static \$model_file_properties = array(\n";
		push @code, "\t\t'$_->{identifier}' => '$_->{property_type}',\n" foreach @model_file_properties;
		push @code, "\t);\n";
	} else {
		push @code, "\tpublic static \$model_file_properties = array();\n";
	}

	if (@model_json_properties) {
		push @code, "\tpublic static \$model_json_properties = array(\n";
		push @code, "\t\t'$_->{identifier}' => '$_->{property_type}',\n" foreach @model_json_properties;
		push @code, "\t);\n";
	} else {
		push @code, "\tpublic static \$model_json_properties = array();\n";
	}

	push @code, "\n";
	my %model_functions;
	foreach my $function (@{$model->{functions}}) {
		die "duplicate function $function->{identifier} defined in model $model->{identifier}"
				if exists $model_functions{$function->{identifier}};
		$model_functions{$function->{identifier}} = 1;

		if ($function->{type} eq 'model_function') {
			push @code, "\tpublic function $function->{identifier} () {\n";
			push @code, map "$_\n", split "\n", $function->{code};
			push @code, "\t}\n";
		} elsif ($function->{type} eq 'model_static_function') {
			push @code, "\tpublic static function $function->{identifier} () {\n";
			push @code, map "$_\n", split "\n", $function->{code};
			push @code, "\t}\n";
		} elsif ($function->{type} eq 'on_event_function') {
			push @code, "\tpublic function $function->{identifier} () {\n";
			push @code, "\t\tparent::$function->{identifier}();\n";
			push @code, map "$_\n", split "\n", $function->{code};
			push @code, "\t}\n";
		} else {
			die "unimplemented function type $function->{type}";
		}
	}
	push @code, "\n";

	# my %casts;
	# foreach my $property (grep $_->{type} eq 'model_pointer_property', @{$model->{properties}}) {
	# 	$casts{$property->{identifier}} = $property->{property_type};
	# }

	# if (%casts) {
	# 	# write the custom getter for these variables
	# 	push @code, "\tpublic function __get(\$name) {\n";
	# 	my $first = 1;
	# 	foreach my $identifier (sort keys %casts) {
	# 		if ($first) {
	# 			push @code, "\t\tif (\$name === '$identifier') {\n";
	# 			$first = 0;
	# 		} else {
	# 			push @code, "\t\t} elseif (\$name === '$identifier') {\n";
	# 		}
	# 		push @code, "\t\t\tif (is_int(\$this->_data['$identifier']))\n";
	# 		push @code, "\t\t\t\t\$this->_data['$identifier'] = \$this->_data['$identifier'] === 0 ? null "
	# 				. ": $casts{$identifier}::get_by_id(\$this->_data['$identifier']);\n";
	# 		# push @code, "\t\t\t}\n";
	# 		push @code, "\t\t\treturn \$this->_data['$identifier'];\n";

	# 	}
	# 	push @code, "\t\t} else\n";
	# 	push @code, "\t\t\treturn parent::__get(\$name);\n";
	# 	push @code, "\t}\n";

	# 	push @code, "\n";

	# 	# write the custom store for these variables
	# 	push @code, "\tpublic static function cast_to_store(\$name, \$value) {\n";
	# 	$first = 1;
	# 	foreach my $identifier (sort keys %casts) {
	# 		if ($first) {
	# 			push @code, "\t\tif (\$name === '$identifier') {\n";
	# 			$first = 0;
	# 		} else {
	# 			push @code, "\t\t} elseif (\$name === '$identifier') {\n";
	# 		}
	# 		push @code, "\t\t\tif (!is_int(\$value))\n";
	# 		push @code, "\t\t\t\t\$value = \$value === null ? 0 "
	# 				. ": \$value->id;\n";
	# 		# push @code, "\t\t\t}\n";
	# 		push @code, "\t\t\treturn \$value;\n";

	# 	}
	# 	push @code, "\t\t} else {\n";
	# 	push @code, "\t\t\treturn parent::cast_to_store(\$name, \$value);\n";
	# 	push @code, "\t\t}\n";
	# 	push @code, "\t}\n";
	# }



	push @code, "}\n";
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
