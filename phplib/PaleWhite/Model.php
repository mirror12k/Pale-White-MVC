<?php

namespace PaleWhite;
// base model class which provides a lot of magic methods for compiled models
abstract class Model {
	public $_data;

	public function __construct(array $data) {
		$this->_data = $data;
	}

	public function __get(string $name) {
		if (isset($this->_data[$name]))
			return $this->_data[$name];
		else
			throw new \Exception("attempted to get undefined model property: $name");
	}

	public function __set(string $name, mixed $value) {
		if (isset($this->_data[$name])) {
			$this->_data[$name] = $value;
			$this->update_fields(array($name => static::cast_to_store($name, $value)));
		} else {
			throw new \Exception("attempted to set undefined model property: $name");
		}
	}

	public static function get_by_id(int $id) {
		// return cached item if available
		if (isset(static::$model_cache['id'][$id]))
			return static::$model_cache['id'][$id];

		global $database;
		$query = $database->select()
				->table(static::$table_name)
				->where(array('id' => $id))
				->limit(1);

		$result = static::get_by_query($query);

		if (count($result) === 0)
			return null;
		else
			return $result[0];
	}

	public static function get_by_query(DatabaseQuery $query) {
		$result = $query->fetch();

		$objects = array();
		foreach ($result as $data) {
			$loaded_data = static::load_data($data);
			$objects[] = new static($data);
		}

		return $objects;
	}

	public static function create(array $data) {
		global $database;
		$query = $database->insert()
				->table(static::$table_name)
				->values($data);

		$result = $query->fetch();
		if ($result === TRUE)
			return static::get_by_id($database->insert_id);
		else
			return null;
	}

	public static function load_data(array $data) {
		$loaded = array();
		foreach ($data as $field => $value) {
			$loaded[$field] = static::cast_from_store($field, $value);
		}
		return $loaded;
	}

	public static function cast_to_store(string $name, mixed $value) {
		return $value;
	}

	public static function cast_from_store(string $name, mixed $value) {
		return $value;
	}

	public function update_fields(array $values) {
		global $database;
		$query = $database->update()
				->table(static::$table_name)
				->values($values)
				->where(array('id' => $this->id));
		
		$query->fetch();
	}
}


