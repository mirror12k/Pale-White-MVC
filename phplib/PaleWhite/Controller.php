<?php

namespace PaleWhite;

abstract class Controller {

	public function route (string $path, array $args) {}
	
	public function validate (string $type, $value) {
		throw new \Exception("undefined validator requested: '$type'");
	}

	public function action (string $action, array $args) {
		throw new \Exception("undefined action requested: '$action'");
	}

	public function load_model(string $model_class, array $args) {
		$object = $model_class::get_by($args);

		if ($object === null)
			throw new \Exception("invalid '$model_class'!");
		
		return $object;
	}
}


