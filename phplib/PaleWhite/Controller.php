<?php

namespace PaleWhite;

abstract class Controller {

	public function route (Request $req, Response $res) {}
	
	public function validate ($type, $value) {
		throw new \Exception("undefined validator requested: '$type'");
	}

	public function action ($action, array $args) {
		throw new \Exception("undefined action requested: '$action'");
	}

	public function render_template($template_class, array $args) {
		$template = new $template_class();
		return $template->render($args);
	}

	public function route_subcontroller($controller_class, Request $req, Response $res) {
		$controller = new $controller_class();
		return $controller->route($req, $res);
	}

	public function load_model($model_class, array $args) {
		$object = $model_class::get_by($args);

		if ($object === null)
			throw new \Exception("invalid '$model_class'!");
		
		return $object;
	}
}


