<?php

namespace PaleWhite;

abstract class FileDirectory {
	// public static $directory = "./mydir";

	public static function accept_file_upload(\PaleWhite\FileUpload $file_upload) {
		$file_hash = hash_file('sha256', $file_upload->temp_filepath);
		$filename = $file_hash;

		if (static::$properties['suffix_timestamp']) {
			$filename .= '_' . time();
		}

		$filepath = static::$directory . '/' . $filename;

		if (file_exists($filepath))
			throw new \PaleWhite\FileException(get_called_class(), "file $filepath already exists");
		if (!move_uploaded_file($file_upload->temp_filepath, $filepath))
			throw new \PaleWhite\FileException(get_called_class(), "failed to move uploaded file: " . $file_upload->temp_filepath);

		return static::load_file($filename);
	}

	public static function load_file($filename) {
		if ($filename === '.' ||$filename === '..' || strpos($filename, '/') !== false)
			throw new \PaleWhite\ValidationException("invalid filename");

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
				throw new \PaleWhite\ValidationException('argument "accept_upload" not a file upload');

			return static::accept_file_upload($file_upload);
		} elseif (isset($args['path'])) {
			$path = $args['path'];
			if (!is_string($path))
				throw new \PaleWhite\ValidationException('argument "path" not a string');

			return static::load_file($path);
		} else {
			throw new \PaleWhite\InvalidException('invalid arguments to file');
		}
	}
}

class FileDirectoryFile {
	public $filename;
	public $filepath;
	public $file_directory_class;

	public $cached_mime_type;

	public function __construct($filename, $filepath, $file_directory_class) {
		$this->filename = $filename;
		$this->filepath = $filepath;
		$this->file_directory_class = $file_directory_class;
	}

	public function delete() {
		return unlink($this->filepath);
	}

	public function __get($name) {
		if ($name === 'mime_type') {
			if (!isset($this->cached_mime_type))
				$this->cached_mime_type = mime_content_type($this->filepath);
			return $this->cached_mime_type;

		} elseif ($name === 'url') {
			if (strpos($this->filepath, "./") !== 0)
				throw new \PaleWhite\InvalidException("file directory path isnt relative for a url path");
			global $config;

			return $config['site_base'] . substr($this->filepath, 1);

		} else {
			throw new \PaleWhite\InvalidException("attempt to get unknown field $name");
		}
	}
}
