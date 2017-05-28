






build:
	sh
		~/src/perl/repo/Sugar/Lang/GrammarCompiler.pm grammar/glass_parser.sugar > PaleWhite/GlassParser.pm
		~/src/perl/repo/Sugar/Lang/GrammarCompiler.pm grammar/model_parser.sugar > PaleWhite/ModelParser.pm
		~/src/perl/repo/Sugar/Lang/GrammarCompiler.pm grammar/controller_parser.sugar > PaleWhite/ControllerParser.pm


