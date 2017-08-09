<?php

namespace PaleWhite;
// base model class which provides a lot of magic methods for compiled models
class FileUpload {
	public $temp_filepath;
	public $file_size;

	public function __construct($temp_filepath, $file_size) {
		$this->temp_filepath = $temp_filepath;
		$this->file_size = $file_size;
	}
}
