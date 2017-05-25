<?php

namespace PaleWhite;
// base model class which provides a lot of magic methods for compiled models
abstract class Model {
	public $_data;

	public function __construct(array $data) {
		$this->_data = $data;
	}

	public function __get(string $name) {
		throw new \Exception("attempted to get undefined model property: $name");
	}

	public function __set(string $name, mixed $value) {
		throw new \Exception("attempted to set undefined model property: $name");
	}

	public static function get_by_id(int $id) {
		// return cached item if available
		if (isset(static::$model_cache['id'][$id]))
			return static::$model_cache['id'][$id];

		global $database;
		$query = $database->select()
				->from(static::$table_name)
				->where(array('id' => $id))
				->limit(1);

		$result = static::get_by_query($query);

		if (count($result) === 0)
			return null;
		else
			return $result[0];
	}

	public static function get_by_query($query) {
		$result = $query->fetch();

		$objects = array();
		foreach ($result as $data) {
			$loaded_data = static::load_data($data);
			$objects[] = new static($data);
		}

		return $objects;
	}
}


