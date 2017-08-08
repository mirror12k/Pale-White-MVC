<?php

namespace PaleWhite;
// base model class which provides a lot of magic methods for compiled models
abstract class Model {
	private $_data;
	private $_loaded = array();

	public function __construct(array $data) {
		$this->_data = $data;
	}

	// model access methods
	public function __get($name) {
		if (isset(static::$model_properties[$name])) {
			if (isset(static::$model_submodel_properties[$name]) && !isset($this->_loaded[$name]))
			{
				$this->_data[$name] = static::get_lazy_loaded_model($name, $this->_data[$name]);
				$this->_loaded[$name] = true;
			}
			return $this->_data[$name];

		} elseif (isset(static::$model_array_properties[$name])) {
			if (!isset($this->_loaded[$name]))
			{
				$this->_data[$name] = static::load_array_data($this->_data['id'], $name);
				if (isset(static::$model_submodel_properties[$name]))
					$this->_data[$name] = static::get_lazy_loaded_model_array($name, $this->_data[$name]);
				$this->_loaded[$name] = true;
			}
			return $this->_data[$name];

		} else
			throw new \Exception("attempted to get undefined model property '$name' in model class: " . get_called_class());
	}

	public function __set($name, $value) {
		if ($name === 'id') {
			throw new \Exception("attempted to set model property 'id' in model class: " . get_called_class());
		} elseif (isset($this->_data[$name])) {
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
				->values(array('parent_id' => $this->_data['id'], 'value' => static::cast_to_store($array_name, $value)));

		$result = $query->fetch();
		if ($result === true) {
			$this->_data[$array_name][] = $value;
			return true;
		} else {
			return false;
		}
	}

	public function remove($array_name, $value, $limit=null) {
		global $database;
		$query = $database->delete()
				->table(static::$table_name . '__array_property__' . $array_name)
				->where(array('parent_id' => $this->_data['id'], 'value' => static::cast_to_store($array_name, $value)));

		if (isset($limit))
			$query->limit($limit);

		$result = $query->fetch();
		return $result;
	}

	public function delete() {
		$this->on_delete();

		global $database;
		$query = $database->delete()
				->table(static::$table_name)
				->where(array('id' => $this->_data['id']));

		unset($this->_model_cache['id'][$this->_data['id']]);

		$result = $query->fetch();
		return $result;
	}

	public function on_create() {}
	public function on_delete() {}

	// model static access/creation methods
	public static function get_by_id($id) {
		// return cached item if available
		if (isset(static::$_model_cache['id'][$id]))
			return static::$_model_cache['id'][$id];

		return static::get_by(array('id' => $id));
	}

	public static function get_multiple_by_id(array $ids_list) {
		// // return cached item if available
		// if (isset(static::$_model_cache['id'][$id]))
		// 	return static::$_model_cache['id'][$id];

		// retrieve the items as a list
		$items = static::get_list(array('id' => $ids_list));
		// order the items by id
		$items_by_id = array();
		foreach ($items as $item)
			$items_by_id[$item->id] = $item;

		// reorder the items by the given ids_list order
		$results = array();
		foreach ($ids_list as $id)
			$results[] = isset($items_by_id[$id]) ? $items_by_id[$id] : null;

		return $results;
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

	public static function get_list(array $values, $limit=null) {
		$values = static::store_data($values);

		global $database;
		$query = $database->select()
				->table(static::$table_name)
				->where($values);

		if (isset($limit))
			$query->limit($limit);

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

			$obj->on_create();

			return $obj;
		} else {
			return null;
		}
	}

	private static function load_data(array $data) {
		$loaded = array();
		foreach ($data as $field => $value) {
			$loaded[$field] = static::cast_from_store($field, $value);
		}
		// foreach (static::$model_array_properties as $field => $field_type) {
		// 	$loaded[$field] = static::load_array_data($data['id'], $field);
		// }
		return $loaded;
	}

	private static function load_array_data($id, $field) {
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

	private static function store_data(array $data) {
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

	private static function store_array_data($field, $value) {
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

	// public static function cast_model_from_store($name, $value) {
	// 	if (!isset(static::$model_submodel_properties[$name]))
	// 		throw new \Exception("attempt to cast model from store on non-model property '$name' in model class: "
	// 				. get_called_class());

	// 	$class = static::$model_submodel_properties[$name];
	// 	$value = (int)$value;
	// 	$value = $value === 0 ? null : $class::get_by_id((int)$value);
	// 	return $value;
	// }

	private static function get_lazy_loaded_model($name, $value) {
		if (!isset(static::$model_submodel_properties[$name]))
			throw new \Exception("attempt to lazy load non-model property '$name' in model class: " . get_called_class());

		$class = static::$model_submodel_properties[$name];
		$value = (int)$value;
		return $value === 0 ? null : $class::get_by_id((int)$value);
		// if (is_int($value) or is_string($value)) {
		// 	$value = static::cast_model_from_store($name, $value);
		// }
		// return $value;
	}

	private static function get_lazy_loaded_model_array($name, $value) {
		if (!isset(static::$model_submodel_properties[$name]))
			throw new \Exception("attempt to lazy load non-model property '$name' in model class: " . get_called_class());
		
		if (count($value) === 0)
			return array();
		$class = static::$model_submodel_properties[$name];
		return $class::get_multiple_by_id($value);
	}

	private function update_fields(array $values) {

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
					->where(array('id' => $this->_data['id']));
			$query->fetch();
		}

		foreach ($array_fields as $field => $value)
			$this->update_array_field($field, $value);
	}

	private function update_array_field($field, $value) {
		$value = static::store_array_data($field, $value);

		global $database;
		$delete_query = $database->delete()
				->table(static::$table_name . '__array_property__' . $field)
				->where(array('parent_id' => $this->_data['id']));
		$delete_query->fetch();

		foreach ($value as $item) {
			$insert_query = $database->insert()
					->table(static::$table_name . '__array_property__' . $field)
					->values(array('parent_id' => $this->_data['id'], 'value' => $item));
			$insert_query->fetch();
		}
	}
}


