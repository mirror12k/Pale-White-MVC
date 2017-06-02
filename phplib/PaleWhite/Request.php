<?php

namespace PaleWhite;

class Request {
	public $path;
	public $args;

	public function __construct($path, array $args) {
		$this->path = $path;
		$this->args = $args;
	}
}
