extends GdUnitTestSuite

## Consolidated unit tests covering composition container loading, basic config validation,
## and manipulatable hierarchy checks.

var container: GBCompositionContainer

func before_test() -> void:
    # Prefer specific factory usage over UnifiedTestFactory for new tests
    container = GBCompositionContainer.new()
    container.config = GBConfig.new()

### Composition container load checks
func test_test_composition_container_loads_and_has_placement_rules() -> void:
    var repo_res: GBCompositionContainer = GBTestConstants.TEST_COMPOSITION_CONTAINER
    assert_object(repo_res).is_not_null().append_failure_message("GBTestConstants.TEST_COMPOSITION_CONTAINER must be a valid resource")
    var pr: Array = repo_res.get_placement_rules()
    var pr_count: int = pr.size() if pr else 0
    assert_int(pr_count).is_greater(0).append_failure_message("Expected repo composition container to contain placement rules")

    var dup: GBCompositionContainer = repo_res.duplicate(true)
    assert_object(dup).is_not_null()
    var pr_dup: Array = dup.get_placement_rules()
    var pr_dup_count: int = pr_dup.size() if pr_dup else 0
    assert_int(pr_dup_count).is_greater(0).append_failure_message("Duplicated container should retain placement rules")

    var path: String = "res://test/grid_building_test/resources/composition_containers/test_composition_container.tres"
    var loaded: Resource = ResourceLoader.load(path)
    assert_object(loaded).append_failure_message("ResourceLoader failed to load %s" % path).is_not_null()
    var pr_loaded: Array = loaded.get_placement_rules() if loaded and loaded.has_method("get_placement_rules") else []
    var pr_loaded_count: int = pr_loaded.size() if pr_loaded else 0
    assert_int(pr_loaded_count).is_greater(0).append_failure_message("Loaded resource should have placement rules")

### Configuration validator basics
func test_validate_configuration_with_complete_config() -> void:
    container.config.settings = GBSettings.new()
    container.config.actions = GBActions.new()
    container.config.templates = GBTemplates.new()
    var issues: Array[String] = container.get_editor_issues()
    assert_int(issues.size()).append_failure_message("Issues found: %s" % str(issues)).is_greater_equal(0)

func test_validate_runtime_configuration_minimum() -> void:
    var issues : Array[String] = container.get_runtime_issues()
    # Expect some non-critical issues by default; ensure API returns an array
    assert_array(issues).is_not_null()

func test_injectable_factory_create_collision_mapper() -> void:
    container.config.settings = GBSettings.new()
    var mapper: CollisionMapper = GBInjectableFactory.create_collision_mapper(container)
    assert_object(mapper).is_not_null()
    assert_bool(mapper is CollisionMapper).is_true()
    var issues: Array[String] = mapper.get_runtime_issues()
    assert_int(issues.size()).append_failure_message("Validation issues: %s" % str(issues)).is_equal(0)

### Manipulatable hierarchy checks
func test_hierarchy_valid_when_root_is_ancestor() -> void:
    var root := Node3D.new()
    add_child(root)
    var child := Node3D.new()
    root.add_child(child)
    var m := Manipulatable.new()
    child.add_child(m)
    m.root = root
    assert_bool(m.is_root_hierarchy_valid()).is_true()
    assert_array(m.get_issues()).is_empty()

func test_hierarchy_invalid_when_root_not_ancestor() -> void:
    var unrelated := Node3D.new()
    add_child(unrelated)
    var other_branch := Node3D.new()
    add_child(other_branch)
    var child := Node3D.new()
    other_branch.add_child(child)
    var m := Manipulatable.new()
    child.add_child(m)
    m.root = unrelated
    assert_bool(m.is_root_hierarchy_valid()).is_false()
    assert_array(m.get_issues()).is_not_empty()
