<?php

namespace PaleWhite;

class FileUpload {
	public $original_filename;
	public $temp_filepath;
	public $file_size;

	public $cached_mime_type;

	public function __construct($original_filename, $temp_filepath, $file_size) {
		$this->original_filename = $original_filename;
		$this->temp_filepath = $temp_filepath;
		$this->file_size = $file_size;
	}

	public function __get($name) {
		if ($name === 'mime_type') {
			if (!isset($this->cached_mime_type))
				$this->cached_mime_type = mime_content_type($this->temp_filepath);
			return $this->cached_mime_type;

		} else {
			throw new \PaleWhite\InvalidException("attempt to get unknown field $name");
		}
	}
}


