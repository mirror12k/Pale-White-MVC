<?php

namespace PaleWhite;

abstract class FileDirectory {
	// public static $directory = "./mydir";

	private static function accept_file_upload(\PaleWhite\FileUpload $file_upload) {
		$file_hash = hash_file('sha256', $file_upload->temp_filepath);
		$filename = $file_hash;

		if (static::$properties['suffix_timestamp']) {
			$filename .= '_' . time();
		}

		$filepath = static::$directory . '/' . $filename;

		if (file_exists($filepath))
			throw new \PaleWhite\FileException(get_called_class(), "file '$filepath' already exists");
		if (!move_uploaded_file($file_upload->temp_filepath, $filepath))
			throw new \PaleWhite\FileException(get_called_class(), "failed to move uploaded file: " . $file_upload->temp_filepath);

		return static::load_file($filename);
	}

	private static function move_existing_file($old_filepath) {
		$file_hash = hash_file('sha256', $old_filepath);
		$filename = $file_hash;

		if (static::$properties['suffix_timestamp']) {
			$filename .= '_' . time();
		}

		$filepath = static::$directory . '/' . $filename;

		if (file_exists($filepath))
			throw new \PaleWhite\FileException(get_called_class(), "file '$filepath' already exists");
		if (!rename($old_filepath, $filepath))
			throw new \PaleWhite\FileException(get_called_class(), "failed to move existing file: " . $old_filepath);

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

		} elseif (isset($args['move_existing'])) {
			$path = (string)$args['move_existing'];
			if (!file_exists($path))
				throw new \PaleWhite\ValidationException('argument "move_existing" not an existing file');
			if (is_uploaded_file($path))
				throw new \PaleWhite\ValidationException('argument "move_existing" is a file upload, file uploads must be loaded through "accept_upload"');

			return static::move_existing_file($path);

		} elseif (isset($args['path'])) {
			$path = (string)$args['path'];
			if (!is_string($path))
				throw new \PaleWhite\ValidationException('argument "path" not a string');

			return static::load_file($path);

		} else {
			throw new \PaleWhite\InvalidException('invalid arguments to file');
		}
	}

	public static function get_file_list($args = array()) {
		if (isset($args['_order']) && $args['order'] === 'descending') {
			$file_list = scandir(static::$directory, SCANDIR_SORT_DESCENDING);
		} else {
			$file_list = scandir(static::$directory, SCANDIR_SORT_ASCENDING);
		}

		$file_list = array_filter($file_list, function ($filename) {
			return $filename !== '.' && $filename !== '..';
		});

		if (isset($args['_offset'])) {
			$file_list = array_slice($file_list, (int)$args['_offset']);
		}
		if (isset($args['_limit'])) {
			$file_list = array_slice($file_list, 0, (int)$args['_limit']);
		}

		$file_objects = array();
		foreach ($file_list as $filename) {
			$file_objects[] = static::load_file($filename);
		}

		return $file_objects;
	}
}

class FileDirectoryFile {
	public $filename;
	public $filepath;
	public $file_directory_class;

	public $cached_mime_type;
	public $cached_filesize;

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

		} elseif ($name === 'filesize') {
			if (!isset($this->cached_filesize))
				$this->cached_filesize = filesize($this->filepath);
			return $this->cached_filesize;

		} elseif ($name === 'url') {
			if (strpos($this->filepath, "./") !== 0)
				throw new \PaleWhite\InvalidException("file directory path isnt relative for a url path");
			global $runtime;
			return $runtime->site_base . substr($this->filepath, 1);

		} else {
			throw new \PaleWhite\InvalidException("attempt to get unknown field $name");
		}
	}
}
