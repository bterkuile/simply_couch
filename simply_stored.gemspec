# frozen_string_literal: true
# -*- encoding: utf-8 -*-
# stub: simply_stored 1.0.0 ruby lib

Gem::Specification.new do |s|
  s.name = "simply_stored"
  s.version = "1.0.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["Mathias Meyer, Jonathan Weiss"]
  s.date = "2012-05-22"
  s.description = "Convenience layer for CouchDB on top of CouchPotato."
  s.email = "info@peritor.com"
  s.extra_rdoc_files = ["LICENSE.txt", "README.md"]
  s.files = ["CHANGELOG.md", "LICENSE.txt", "README.md", "lib/simply_stored.rb", "lib/simply_stored/class_methods_base.rb", "lib/simply_stored/couch.rb", "lib/simply_stored/couch/ancestry.rb", "lib/simply_stored/couch/association_property.rb", "lib/simply_stored/couch/belongs_to.rb", "lib/simply_stored/couch/database.rb", "lib/simply_stored/couch/embedded_in.rb", "lib/simply_stored/couch/ext/couch_potato.rb", "lib/simply_stored/couch/find_by.rb", "lib/simply_stored/couch/finders.rb", "lib/simply_stored/couch/has_and_belongs_to_many.rb", "lib/simply_stored/couch/has_many.rb", "lib/simply_stored/couch/has_many_embedded.rb", "lib/simply_stored/couch/has_one.rb", "lib/simply_stored/couch/pagination.rb", "lib/simply_stored/couch/pagination_options.rb", "lib/simply_stored/couch/properties.rb", "lib/simply_stored/couch/validations.rb", "lib/simply_stored/couch/views.rb", "lib/simply_stored/couch/views/array_property_view_spec.rb", "lib/simply_stored/couch/views/deleted_model_view_spec.rb", "lib/simply_stored/include_relation.rb", "lib/simply_stored/instance_methods.rb", "lib/simply_stored/locale/en.yml", "lib/simply_stored/rake.rb", "lib/simply_stored/storage.rb", "test/belongs_to_test.rb", "test/conflict_handling_test.rb", "test/finder_test.rb", "test/fixtures/couch.rb", "test/has_and_belongs_to_many_test.rb", "test/has_many_test.rb", "test/has_one_test.rb", "test/instance_lifecycle_test.rb", "test/mass_assignment_protection_test.rb", "test/s3_test.rb", "test/soft_deletable_test.rb", "test/test_helper.rb", "test/validations_test.rb", "test/views_test.rb"]
  s.homepage = "http://github.com/peritor/simply_stored"
  s.rdoc_options = ["--charset=UTF-8"]
  s.rubygems_version = "3.4.20"
  s.summary = "Convenience layer for CouchDB"
  s.test_files = ["test/belongs_to_test.rb", "test/conflict_handling_test.rb", "test/finder_test.rb", "test/fixtures/couch.rb", "test/has_and_belongs_to_many_test.rb", "test/has_many_test.rb", "test/has_one_test.rb", "test/instance_lifecycle_test.rb", "test/mass_assignment_protection_test.rb", "test/s3_test.rb", "test/soft_deletable_test.rb", "test/test_helper.rb", "test/validations_test.rb", "test/views_test.rb"]

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<activesupport>, [">= 0"])
  s.add_runtime_dependency(%q<activemodel>, [">= 0"])
  s.add_development_dependency(%q<couchrest>, [">= 0"])
end
