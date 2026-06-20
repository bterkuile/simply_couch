# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name        = "simply_couch"
  s.version     = "0.2.0"
  s.license     = "MIT"

  s.summary     = "Simple CouchDB ORM for Rails"
  s.description = "CouchDB ORM with ActiveModel compliance, associations, validations, callbacks, views, and soft delete. No driver dependency — the host app brings its own CouchDB client."
  s.authors     = ["Benjamin ter Kuile"]
  s.email       = "bterkuile@gmail.com"
  s.homepage    = "https://github.com/bterkuile/simply_couch"

  s.required_ruby_version = ">= 3.1"

  s.metadata = {
    "source_code_uri"   => "https://github.com/bterkuile/simply_couch",
    "bug_tracker_uri"   => "https://github.com/bterkuile/simply_couch/issues",
    "changelog_uri"     => "https://github.com/bterkuile/simply_couch/blob/main/CHANGELOG.md",
    "rubygems_mfa_required" => "true"
  }

  s.files = Dir[
    "lib/**/*.rb",
    "lib/**/*.yml",
    "LICENSE.txt",
    "README.md",
    "CHANGELOG.md"
  ]

  s.require_paths = ["lib"]

  s.add_dependency "activemodel",  ">= 6.0"
  s.add_dependency "activesupport", ">= 6.0"

  s.add_development_dependency "rspec", "~> 3.0"
  s.add_development_dependency "couchrest", ">= 0"
end
