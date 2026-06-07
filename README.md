# SimplyCouch

[![Gem Version](https://badge.fury.io/rb/simply_couch.svg)](https://rubygems.org/gems/simply_couch)
[![License](https://img.shields.io/badge/license-BSD--2--Clause-blue.svg)](LICENSE.txt)

**Simple CouchDB ORM for Rails** — ActiveModel-compliant, driver-agnostic.

Zero driver dependencies. Your app brings its own CouchDB client (couchrest, couchbase, etc.).

## History

SimplyCouch is based on **[simply_stored](https://github.com/peritor/simply_stored)** (140 ★), created by [Mathias Meyer](https://github.com/roidrage) and [Jonathan Weiss](https://github.com/jweiss) at [Peritor Consulting](https://github.com/peritor) in Berlin (~2010). simply_stored was a convenience layer on top of [CouchPotato](https://github.com/langalex/couch_potato).

This fork evolved over a decade with substantial additions — pagination, ancestry trees, embedded documents, include relations, multi-database support, and a migration toward ActiveModel. In 2026, the CouchPotato dependency was fully removed (~930 lines of view system + persistence ported directly into the gem), couchrest was removed from the gemspec, and the gem was renamed to **SimplyCouch** as its own project.

**Where are the original authors?** Jonathan Weiss (jweiss) co-founded Scalarium and is active in the Berlin tech scene. Mathias Meyer (roidrage) moved to Amazon Web Services Germany. Peritor's [webistrano](https://github.com/peritor/webistrano) (868 ★) was widely used in the Capistrano era.

## Installation

```ruby
gem 'simply_couch'
```

Or from git:

```ruby
gem 'simply_couch', git: 'https://github.com/bterkuile/simply_couch.git'
```

You must also add a CouchDB client to your Gemfile (the gem doesn't force one):

```ruby
gem 'couchrest'  # or couchbase, or any CouchDB HTTP client
```

## Quick Start

```ruby
class User
  include SimplyCouch::Model

  property :name
  property :email
  property :active, type: Boolean
  property :last_login, type: Time
  property :tags, type: Array

  has_many :posts
  belongs_to :company

  view :by_name, key: :name
  view :active_by_created, key: :created_at, conditions: 'doc.active == true'
end

class Post
  include SimplyCouch::Model

  property :title
  property :body

  belongs_to :user
end

# CRUD
user = User.create(name: 'Alice', email: 'alice@example.com', active: true)
user.update(name: 'Alice B.')
user.destroy

# Queries
User.find_by_name('Alice')
User.find_all_by_active(true)
User.active_by_created(descending: true)
User.all(page: 1, per_page: 40)

# Associations
user.posts                     # => [Post, ...]
user.posts(limit: 5, order: :desc)
user.post_count                # => 42
```

## Features

### Properties & Type Casting

```ruby
property :name
property :age,        type: Integer
property :price,      type: Float
property :active,     type: Boolean   # stored as true/false
property :last_login, type: Time
property :tags,       type: Array
property :metadata,   type: Hash
```

### Associations

`belongs_to`, `has_many`, `has_many_embedded`, `has_and_belongs_to_many`, `has_one`, `embedded_in`.

```ruby
class Post
  include SimplyCouch::Model
  has_many :comments, dependent: :destroy
  has_many :authors, through: :comments, source: :user
  belongs_to :category
end

class User
  include SimplyCouch::Model
  has_and_belongs_to_many :networks, storing_keys: true
end
```

### Validations

Standard ActiveModel validations plus a `containment` validator for array properties:

```ruby
class Page
  include SimplyCouch::Model
  property :categories
  validates_containment_of :categories, in: %w[news blog docs]
end
```

### Callbacks

`before_save`, `after_save`, `before_create`, `after_create`, `before_destroy`, `after_destroy` — all standard ActiveModel callbacks.

### Views

CouchDB views are auto-generated from your model's property declarations. JavaScript only (Erlang dropped in 2026 port).

```ruby
view :by_status, key: :status
view :published, key: :created_at, conditions: 'doc.status == "published"'
view :by_tags, key: :tags  # array properties work too
```

Custom views and raw map/reduce are supported via view spec classes.

### Pagination

```ruby
Post.all(page: 2, per_page: 25)
User.active_by_created(page: 1, per_page: 50, descending: true)
```

### Soft Delete

```ruby
class Document
  include SimplyCouch::Model
  enable_soft_delete  # defaults to :deleted_at
end

doc = Document.create(title: 'draft')
doc.destroy
Document.all                          # => [] (soft-deleted filtered out)
Document.all(with_deleted: true)      # => [doc] (recoverable)
```

### Ancestry (Tree Structures)

```ruby
class Page
  include SimplyCouch::Model
  property :title
  has_ancestry
end

# Build trees
parent = Page.create(title: 'Products')
child = Page.create(title: 'Widgets', parent: parent)

# Query trees
Page.roots                    # pages with no parent
Page.full_tree                # entire tree loaded in one query
parent.children               # direct children
parent.descendants            # all descendants (flattened)
child.ancestors               # path to root

# Scoped trees (different trees per property)
has_ancestry by_property: :locale
```

### Dynamic Finders

```ruby
User.find_by_name('Alice')
User.find_all_by_active(true)
User.count_by_active(true)
```

### Include Relations

Eager-load associations to avoid N+1 queries on CouchDB:

```ruby
Post.all(include: :user)              # loads users with posts
Post.all(include: [:user, :comments]) # multiple associations
```

### Conflict Resolution

Auto-merge on CouchDB conflicts by default (can be disabled):

```ruby
User.auto_conflict_resolution_on_save = false  # disable
```

### Multi-Database Support

```ruby
class ArchivedPost
  include SimplyCouch::Model
  use_database 'http://couchdb:5984/archive'
end
```

### Design Document Splitting

Prevent full view reindexing when adding a new view:

```ruby
class Post
  include SimplyCouch::Model
  split_design_documents_per_view  # each view → own _design doc

  view :by_user_id, key: :user_id   # → _design/Post_view_by_user_id
  view :by_status,  key: :status    # → _design/Post_view_by_status
end
```

Without splitting, changing any view reindexes all views. On large databases, this can take hours.
With splitting, only the new/changed view reindexes.

### Attachments

SimplyCouch supports **two** attachment strategies — use the one that fits your use case:

#### 1. CouchDB Native Inline Attachments

```ruby
class Invoice
  include SimplyCouch::Model
  include SimplyCouch::Model::Attachments
end

invoice.put_attachment('receipt.pdf', file, content_type: 'application/pdf')
invoice.fetch_attachment('receipt.pdf')
invoice.delete_attachment('receipt.pdf')
invoice.attachment_names  # => ['receipt.pdf', 'logo.png']
```

Attachments are stored inline in the CouchDB document — atomic, no extra storage, replicable.

#### 2. ActiveStorage Compatibility

*Coming soon — `has_one_attached` / `has_many_attached` backed by CouchDB attachments.*

See `docs/attachments.md` for a detailed comparison of approaches.

### Legacy: S3 Attachments

The `has_s3_attachment` method (using RightAws) exists but is **unmaintained and untested**.
It was part of the original simply_stored and has not been verified in years. Use CouchDB
native attachments or ActiveStorage instead.

## Dependencies

| Gem | Version | Notes |
|-----|---------|-------|
| activemodel | >= 6.0 | Validations, callbacks, dirty tracking |
| activesupport | >= 6.0 | Inflections, callbacks, concern |

**No CouchDB driver dependency.** Add `couchrest` or `couchbase` to your app's Gemfile.

## Testing

Uses RSpec with an in-memory CouchDB via [RockingChair](https://github.com/jweiss/rocking_chair).

```bash
bundle exec rspec
```

## License

BSD 2-Clause — see [LICENSE.txt](LICENSE.txt)

## Credits

- **Original simply_stored:** [Mathias Meyer](https://github.com/roidrage) & [Jonathan Weiss](https://github.com/jweiss) at [Peritor Consulting](https://github.com/peritor)
- **Fork & simply_couch:** [Benjamin ter Kuile](https://github.com/bterkuile)
- **CouchPotato removal + 2026 port:** BenClaw & Benjamin ter Kuile
