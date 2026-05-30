# -*- encoding: utf-8 -*-
# stub: simply_stored 1.0.0 ruby lib

Gem::Specification.new do |s|
  s.name = "simply_stored".freeze
  s.version = "1.0.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Mathias Meyer, Jonathan Weiss".freeze]
  s.date = "2012-05-22"
  s.description = "Convenience layer for CouchDB on top of CouchPotato.".freeze
  s.email = "info@peritor.com".freeze
  s.extra_rdoc_files = ["LICENSE.txt".freeze, "README.md".freeze]
  s.files = ["CHANGELOG.md".freeze, "LICENSE.txt".freeze, "README.md".freeze, "lib/simply_stored.rb".freeze, "lib/simply_stored/class_methods_base.rb".freeze, "lib/simply_stored/couch.rb".freeze, "lib/simply_stored/couch/ancestry.rb".freeze, "lib/simply_stored/couch/association_property.rb".freeze, "lib/simply_stored/couch/belongs_to.rb".freeze, "lib/simply_stored/couch/database.rb".freeze, "lib/simply_stored/couch/embedded_in.rb".freeze, "lib/simply_stored/couch/ext/couch_potato.rb".freeze, "lib/simply_stored/couch/find_by.rb".freeze, "lib/simply_stored/couch/finders.rb".freeze, "lib/simply_stored/couch/has_and_belongs_to_many.rb".freeze, "lib/simply_stored/couch/has_many.rb".freeze, "lib/simply_stored/couch/has_many_embedded.rb".freeze, "lib/simply_stored/couch/has_one.rb".freeze, "lib/simply_stored/couch/pagination.rb".freeze, "lib/simply_stored/couch/pagination_options.rb".freeze, "lib/simply_stored/couch/properties.rb".freeze, "lib/simply_stored/couch/validations.rb".freeze, "lib/simply_stored/couch/views.rb".freeze, "lib/simply_stored/couch/views/array_property_view_spec.rb".freeze, "lib/simply_stored/couch/views/deleted_model_view_spec.rb".freeze, "lib/simply_stored/include_relation.rb".freeze, "lib/simply_stored/instance_methods.rb".freeze, "lib/simply_stored/locale/en.yml".freeze, "lib/simply_stored/rake.rb".freeze, "lib/simply_stored/storage.rb".freeze, "test/belongs_to_test.rb".freeze, "test/conflict_handling_test.rb".freeze, "test/finder_test.rb".freeze, "test/fixtures/couch.rb".freeze, "test/has_and_belongs_to_many_test.rb".freeze, "test/has_many_test.rb".freeze, "test/has_one_test.rb".freeze, "test/instance_lifecycle_test.rb".freeze, "test/mass_assignment_protection_test.rb".freeze, "test/s3_test.rb".freeze, "test/soft_deletable_test.rb".freeze, "test/test_helper.rb".freeze, "test/validations_test.rb".freeze, "test/views_test.rb".freeze]
  s.homepage = "http://github.com/peritor/simply_stored".freeze
  s.rdoc_options = ["--charset=UTF-8".freeze]
  s.rubygems_version = "3.4.20".freeze
  s.summary = "Convenience layer for CouchDB".freeze
  s.test_files = ["test/belongs_to_test.rb".freeze, "test/conflict_handling_test.rb".freeze, "test/finder_test.rb".freeze, "test/fixtures/couch.rb".freeze, "test/has_and_belongs_to_many_test.rb".freeze, "test/has_many_test.rb".freeze, "test/has_one_test.rb".freeze, "test/instance_lifecycle_test.rb".freeze, "test/mass_assignment_protection_test.rb".freeze, "test/s3_test.rb".freeze, "test/soft_deletable_test.rb".freeze, "test/test_helper.rb".freeze, "test/validations_test.rb".freeze, "test/views_test.rb".freeze]

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<couch_potato>.freeze, [">= 1.7.0"])
  s.add_runtime_dependency(%q<activesupport>.freeze, [">= 0"])
end
