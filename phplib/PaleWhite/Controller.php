<?php



namespace PaleWhite;

abstract class Controller {

	public function route (Request $req, Response $res) {}
	public function route_ajax (Request $req, Response $res) {}

	public function route_event ($event, array $args) {
		throw new \PaleWhite\InvalidException("undefined event requested: '$event'");
	}
	
	public function validate ($type, $value) {
		throw new \PaleWhite\InvalidException("undefined validator requested: '$type'");
	}

	public function action ($action, array $args) {
		throw new \PaleWhite\InvalidException("undefined action requested: '$action'");
	}

	public function render_template($template_class, array $args) {
		$template = new $template_class();
		return $template->render($args);
	}

	public function route_subcontroller($controller_class, $path, array $args, Response $res) {
		$controller = new $controller_class();
		$req = new Request($path, $args);
		return $controller->route($req, $res);
	}

	public function load_model($model_class, array $args) {
		$object = $model_class::get_by($args);

		if ($object === null)
			throw new \PaleWhite\ValidationException("invalid '$model_class'!");
		
		return $object;
	}

	public function create_model($model_class, array $args) {
		$object = $model_class::create($args);

		if ($object === null)
			throw new \PaleWhite\ValidationException("failed to create '$model_class'!");
		
		return $object;
	}

	public function load_file($file_directory, array $args) {
		$file = $file_directory::file($args);

		if ($file === null)
			throw new \PaleWhite\ValidationException("invalid file!");
		
		return $file;
	}

	public function validate_csrf_token($token) {
		if (!hash_equals($_SESSION['pale_white_csrf_token'], $token))
			throw new \PaleWhite\ValidationException("incorrect csrf token");
	}
}


