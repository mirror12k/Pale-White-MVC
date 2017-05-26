#!/usr/bin/env perl
package PaleWhite::ModelPHPCompiler;
use strict;
use warnings;

use feature 'say';

use Data::Dumper;

use PaleWhite::ModelParser;



sub compile {
	my ($tree) = @_;

	my $code = "<?php\n\n\n";
	$code .= join '', compile_model($_) foreach @$tree;

	return $code
}


sub compile_model {
	my ($model) = @_;

	my %model_functions;

	my @code;
	push @code, "class $model->{identifier} extends \\PaleWhite\\Model {\n";
	push @code, "\tpublic static \$table_name = '$model->{identifier}';\n";

	push @code, "\tpublic static \$model_cache = array('id' => array());\n";
	# push @code, "\t\t'id' => array(),\n";
	# foreach my $property (@{$model->{properties}}) {
	# 	push @code, "\t\t'$property->{identifier}' => array(),\n";
	# }
	# push @code, "\t);\n";

	push @code, "\tpublic static \$model_properties = array(\n";
	push @code, "\t\t'id' => 'int',\n";
	push @code, "\t\t'$_->{identifier}' => '$_->{property_type}',\n" foreach @{$model->{properties}};
	push @code, "\t);\n";

	push @code, "\n";
	foreach my $function (@{$model->{functions}}) {
		die "duplicate function $function->{identifier} defined in model $model->{identifier}"
				if exists $model_functions{$function->{identifier}};
		$model_functions{$function->{identifier}} = 1;

		if ($function->{type} eq 'model_function') {
			my $function_code = "\tpublic function $function->{identifier} () $function->{code}";
			push @code, map "$_\n", split "\n", $function_code;
		} elsif ($function->{type} eq 'model_static_function') {
			my $function_code = "\tpublic static function $function->{identifier} () $function->{code}";
			push @code, map "$_\n", split "\n", $function_code;
		} else {
			die "unimplemented function type $function->{type}";
		}
	}

	push @code, "}\n";
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
