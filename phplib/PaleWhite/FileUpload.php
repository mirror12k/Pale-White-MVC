<?php

namespace PaleWhite;

class FileUpload {
	public $temp_filepath;
	public $file_size;

	public function __construct($temp_filepath, $file_size) {
		$this->temp_filepath = $temp_filepath;
		$this->file_size = $file_size;
	}
}

abstract class FileDirectory {
	// public static $directory = "./mydir";

	public static function accept_file_upload(\PaleWhite\FileUpload $file_upload) {
		$file_hash = hash_file('sha256', $file_upload->temp_filepath);
		$filepath = static::$directory . '/' . $file_hash;

		if (file_exists($filepath))
			throw new \Exception("file $filepath already exists");
		if (!move_uploaded_file($file_upload->temp_filepath, $filepath))
			throw new \Exception("failed to move uploaded file: " . $file_upload->temp_filepath);

		return static::load_file($file_hash);
	}

	public static function load_file($filename) {
		if ($filename === '.' ||$filename === '..' || strpos($filename, '/') !== false)
			throw new \Exception("invalid filename");

		$filepath = static::$directory . '/' . $filename;
		if (file_exists($filepath)) {
			return new FileDirectoryFile($filename, $filepath, get_called_class());
		} else {
			return null;
		}
	}

	public static function file($args) {
		if (isset($args['accept_upload'])) {
			$file_upload = $args['accept_upload'];
			if (!$file_upload instanceof \PaleWhite\FileUpload)
				throw new \Exception('argument "accept_upload" not a file upload');

			return static::accept_file_upload($file_upload);
		} elseif (isset($args['path'])) {
			$path = $args['path'];
			if (!is_string($path))
				throw new \Exception('argument "path" not a string');

			return static::load_file($path);
		} else {
			throw new \Exception('invalid arguments to file');
		}
	}
}

class FileDirectoryFile {
	public $filename;
	public $filepath;
	public $file_directory_class;

	public function __construct($filename, $filepath, $file_directory_class) {
		$this->filename = $filename;
		$this->filepath = $filepath;
		$this->file_directory_class = $file_directory_class;
	}

	public function delete_file() {
		return unlink($this->filepath);
	}
}
