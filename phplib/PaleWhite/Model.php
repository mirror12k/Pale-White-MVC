<?php

namespace PaleWhite;
// base model class which provides a lot of magic methods for compiled models
abstract class Model {
	public $_data;

	public function __construct(array $data) {
		$this->_data = $data;
	}

	public function __get($name) {
		// if (isset($this->_data[$name])) {
		if (isset(static::$model_properties[$name])) {
			if (isset(static::$model_submodel_properties[$name]))
				$this->_data[$name] = $this->get_lazy_loaded_model($name, $this->_data[$name]);
			return $this->_data[$name];
		} elseif (isset(static::$model_array_properties[$name])) {
			if (isset(static::$model_submodel_properties[$name]))
				$this->_data[$name] = $this->get_lazy_loaded_model_array($name, $this->_data[$name]);
			return $this->_data[$name];
		} else
			throw new \Exception("attempted to get undefined model property '$name' in model class: " . get_called_class());
	}

	public function get_lazy_loaded_model($field, $value) {
		if (is_int($value) or is_string($value)) {
			$class = static::$model_submodel_properties[$field];
			$value = $value === 0 ? null : $class::get_by_id((int)$value);
		}
		return $value;
	}

	public function get_lazy_loaded_model_array($field, $value) {
		$loaded_value = array();
		foreach ($value as $item)
			$loaded_value[] = $this->get_lazy_loaded_model($field, $item);
		return $loaded_value;
	}

	public function __set($name, $value) {
		if (isset($this->_data[$name])) {
			$this->_data[$name] = $value;
			$this->update_fields(array($name => $value));
		} else {
			throw new \Exception("attempted to set undefined model property '$name' in model class: " . get_called_class());
		}
	}

	public function add($array_name, $value) {
		global $database;
		$query = $database->insert()
				->table(static::$table_name . '__array_property__' . $array_name)
				->values(array('parent_id' => $this->id, 'value' => static::cast_to_store($array_name, $value)));

		$result = $query->fetch();
		if ($result === true) {
			$this->_data[$array_name][] = $value;
			return true;
		} else {
			return false;
		}
	}

	public static function get_by_id($id) {
		// return cached item if available
		if (isset(static::$model_cache['id'][$id]))
			return static::$model_cache['id'][$id];

		return static::get_by(array('id' => $id));
	}

	public static function get_by(array $values) {
		$values = static::store_data($values);

		global $database;
		$query = $database->select()
				->table(static::$table_name)
				->where($values)
				->limit(1);

		$result = static::get_by_query($query);

		if (count($result) === 0)
			return null;
		else
			return $result[0];
	}

	public static function get_list(array $values) {
		$values = static::store_data($values);

		global $database;
		$query = $database->select()
				->table(static::$table_name)
				->where($values);

		$result = static::get_by_query($query);

		return $result;
	}

	public static function get_by_query(DatabaseQuery $query) {
		$result = $query->fetch();

		$objects = array();
		foreach ($result as $data) {
			$data = static::load_data($data);
			$objects[] = new static($data);
		}

		return $objects;
	}

	public static function create(array $data) {
		$data = static::store_data($data);

		$item_fields = array();
		$array_fields = array();
		foreach ($data as $field => $value) {
			if (isset(static::$model_properties[$field]))
				$item_fields[$field] = $value;
			elseif (isset(static::$model_array_properties[$field]))
				$array_fields[$field] = $value;
			else
				throw new \Exception("attempted to create undefined model property '$field' in model class: " . get_called_class());
		}

		global $database;
		$query = $database->insert()
				->table(static::$table_name)
				->values($item_fields);
		$result = $query->fetch();

		if ($result === TRUE) {
			$obj_id = $database->insert_id;
			$obj = static::get_by_id($obj_id);
			if ($obj === null)
				throw new \Exception("fatal error creating object (id $obj_id): " . get_called_class());

			// have the object update the array fields itself
			foreach ($array_fields as $field => $value) {
				$obj->$field = $value;
			}

			return $obj;
		} else {
			return null;
		}
	}

	public static function load_data(array $data) {
		$loaded = array();
		foreach ($data as $field => $value) {
			$loaded[$field] = static::cast_from_store($field, $value);
		}
		foreach (static::$model_array_properties as $field => $field_type) {
			$loaded[$field] = static::load_array_data($data['id'], $field);
		}
		return $loaded;
	}
	public static function load_array_data($id, $field) {
		global $database;
		$query = $database->select()
				->table(static::$table_name . '__array_property__' . $field)
				->fields(array('value'))
				->where(array('parent_id' => $id));
		$result = $query->fetch();

		$array = array();
		foreach ($result as $row)
			$array[] = static::cast_from_store($field, $row['value']);

		return $array;
	}

	public static function store_data(array $data) {
		$stored = array();
		foreach ($data as $field => $value) {
			if (isset(static::$model_properties[$field]))
				$stored[$field] = static::cast_to_store($field, $value);
			elseif (isset(static::$model_array_properties[$field]))
				$stored[$field] = static::store_array_data($field, $value);
			else
				throw new \Exception("attempted to cast undefined model property '$field' in model class: " . get_called_class());
		}
		return $stored;
	}

	public static function store_array_data($field, $value) {
		$stored_array = array();
		foreach ($value as $item)
			$stored_array[] = static::cast_to_store($field, $item);
		return $stored_array;
	}

	public static function cast_to_store($name, $value) {
		if (isset(static::$model_submodel_properties[$name])) {
			if (is_object($value)) {
				$value = $value->id;
			} elseif ($value === null) {
				$value = 0;
			}
		}
		return $value;
	}

	public static function cast_from_store($name, $value) {
		return $value;
	}

	public function update_fields(array $values) {

		$item_fields = array();
		$array_fields = array();
		foreach ($values as $field => $value) {
			if (isset(static::$model_properties[$field]))
				$item_fields[$field] = $value;
			elseif (isset(static::$model_array_properties[$field]))
				$array_fields[$field] = $value;
			else
				throw new \Exception("attempted to update undefined model property '$field' in model class: " . get_called_class());
		}


		if (count($item_fields) > 0) {
			$item_fields = static::store_data($item_fields);

			global $database;
			$query = $database->update()
					->table(static::$table_name)
					->values($item_fields)
					->where(array('id' => $this->id));
			$query->fetch();
		}

		foreach ($array_fields as $field => $value)
			$this->update_array_field($field, $value);
	}

	public function update_array_field($field, $value) {
		$value = static::store_array_data($field, $value);

		global $database;
		$delete_query = $database->delete()
				->table(static::$table_name . '__array_property__' . $field)
				->where(array('parent_id' => $this->id));
		$delete_query->fetch();

		foreach ($value as $item) {
			$insert_query = $database->insert()
					->table(static::$table_name . '__array_property__' . $field)
					->values(array('parent_id' => $this->id, 'value' => $item));
			$insert_query->fetch();
		}
	}
}


