<?php

namespace PaleWhite;

// generic system exception that should not be caught
class PaleWhiteException extends \Exception {
	public function __construct($message, $code = 0, Exception $previous = null) {
		parent::__construct("[PaleWhite]: $message", $code, $previous);
	}
}

// triggers when issues occur in the database
class DatabaseException extends \Exception {}

// triggers when incorrect use input is sent
class ValidationException extends \Exception {}

// triggers when the framework is used incorrectly (like passing invalid arguments)
class InvalidException extends \Exception {}

// triggers when correct input still triggers an issue somewhere
class ModelException extends \Exception {
	public function __construct($model_class, $message, $code = 0, Exception $previous = null) {
		parent::__construct("[model::$model_class]: $message", $code, $previous);
	}
}

// triggers when correct input still triggers an issue somewhere
class FileException extends \Exception {
	public function __construct($file_class, $message, $code = 0, Exception $previous = null) {
		parent::__construct("[file::$file_class]: $message", $code, $previous);
	}
}

