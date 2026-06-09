# SimplyCouch

[![Gem Version](https://badge.fury.io/rb/simply_couch.svg)](https://rubygems.org/gems/simply_couch)
[![License](https://img.shields.io/badge/license-BSD--2--Clause-blue.svg)](LICENSE.txt)

**Relational conveniences on top of a document store.**

SimplyCouch brings ActiveRecord-style associations, validations, callbacks, and query patterns to CouchDB — without trying to be ActiveRecord. It embraces the document model while giving you the relational tooling you already know.

```ruby
class User
  include SimplyCouch::Model

  property :name
  property :email

  has_many :posts
  belongs_to :company
end
```

*A descendant of [simply_stored](https://github.com/peritor/simply_stored), stripped of its legacy dependencies in 2026 and evolved into a standalone ActiveModel-compliant ORM.*

## Installation

```ruby
gem 'simply_couch'
```

You bring the CouchDB client — the gem doesn't force one:

```ruby
gem 'couchrest'  # or couchbase, or any CouchDB driver
```

## Quick Start

```ruby
class Post
  include SimplyCouch::Model

  property :title
  property :body
  property :published, type: Boolean, default: false
  property :tags, type: Array

  belongs_to :author, class_name: 'User'
  has_many :comments, dependent: :destroy

  view :by_title, key: :title
  view :published_by_date, key: :created_at, conditions: 'doc.published == true'
end

# CRUD
post = Post.create(title: 'Hello World', body: '...')
post.update(title: 'Hello SimplyCouch')
post.destroy

# Queries
Post.find_by_title('Hello World')
Post.published_by_date(descending: true)
Post.all(page: 1, per_page: 40)

# Associations
post.author              # => User
post.comments            # => [Comment, ...]
post.comment_count       # => 42
Post.all(include: :author)  # eager-load to avoid N+1
```

## Features

### Properties & Type Casting

```ruby
property :name
property :age,        type: Integer
property :price,      type: Float
property :active,     type: Boolean
property :last_login, type: Time
property :tags,       type: Array
property :metadata,   type: Hash
```

### Associations

`belongs_to`, `has_many`, `has_one`, `has_many_embedded`, `has_and_belongs_to_many`, `embedded_in`.

```ruby
class Post
  include SimplyCouch::Model
  has_many :comments, dependent: :destroy
  has_many :authors, through: :comments, source: :user
  belongs_to :category
end
```

### Validations

Standard ActiveModel validations plus a `containment` validator:

```ruby
class Page
  include SimplyCouch::Model
  property :categories, type: Array
  validates_containment_of :categories, in: %w[news blog docs]
end
```

### Callbacks

`before_save`, `after_save`, `before_create`, `after_create`, `before_destroy`, `after_destroy` — all standard ActiveModel callbacks.

### Views (Queries)

CouchDB views are auto-generated from property declarations. JavaScript map/reduce.

```ruby
view :by_status, key: :status
view :published, key: :created_at, conditions: 'doc.status == "published"'
```

Custom views and raw map/reduce are supported via view spec classes.

### Pagination

```ruby
Post.all(page: 2, per_page: 25)
User.by_name(page: 1, per_page: 50, descending: true)
```

### Soft Delete

```ruby
class Document
  include SimplyCouch::Model
  enable_soft_delete  # defaults to :deleted_at
end

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

parent = Page.create(title: 'Products')
child  = Page.create(title: 'Widgets', parent: parent)

Page.roots              # pages with no parent
Page.full_tree          # entire tree in one query
parent.children         # direct children
parent.descendants      # all descendants (flattened)
child.ancestors         # path to root
```

Scoped trees: `has_ancestry by_property: :locale`

### Dynamic Finders

```ruby
User.find_by_name('Alice')
User.find_all_by_active(true)
User.count_by_active(true)
```

### Conflict Resolution

Auto-merge on CouchDB conflicts by default. Disable per model:

```ruby
User.auto_conflict_resolution_on_save = false
```

### Multi-Database Support

```ruby
class ArchivedPost
  include SimplyCouch::Model
  use_database 'http://couchdb:5984/archive'
end
```

### Design Document Splitting

Prevent full reindexing when adding a view — each view gets its own design document:

```ruby
class Post
  include SimplyCouch::Model
  split_design_documents_per_view

  view :by_user_id, key: :user_id   # → _design/Post_view_by_user_id
  view :by_status,  key: :status    # → _design/Post_view_by_status
end
```

### Attachments

Three attachment strategies, all usable together on the same model:

#### CouchDB Native (`has_couch_attached`)

Attachments stored inline in the CouchDB document — atomic, replicable, no extra storage.

```ruby
class Invoice
  include SimplyCouch::Model
  has_couch_attached :receipt
end

invoice.receipt = File.read('receipt.pdf')
invoice.save                           # attachment uploaded to CouchDB
invoice.receipt_url                    # fetch URL
invoice.delete_couch_attachment(:receipt)
```

#### Local Filesystem (`has_local_attached`)

Paperclip-compatible local file storage with postprocessing.

```ruby
class Product
  include SimplyCouch::Model
  has_local_attached :photo, styles: { thumb: '100x100', medium: '300x300' }
end

product.photo = uploaded_file
product.photo.url(:thumb)              # => "/system/product/photos/.../thumb.jpg"
```

#### S3 (`has_s3_attached`)

AWS S3 or any S3-compatible service (MinIO, etc.).

```ruby
class Report
  include SimplyCouch::Model
  has_s3_attached :pdf, bucket: 'reports'
end

report.pdf = File.read('monthly.pdf')
report.save                            # uploads to S3
report.pdf_url                         # presigned URL
```

Configure defaults:

```ruby
# config/initializers/simply_couch.rb
SimplyCouch.s3_defaults = {
  bucket: 'myapp',
  access_key: ENV['S3_ACCESS_KEY'],
  secret_access_key: ENV['S3_SECRET_KEY']
}

# Or from Rails credentials:
SimplyCouch.s3_defaults = Rails.application.credentials.s3
```

## Architecture

SimplyCouch is designed to be **database-agnostic**. All CouchDB-specific calls are isolated in the persistence adapter — the model layer only speaks in terms of documents, views, and associations. This means:

- **Swap backends** without touching model code
- **Test against in-memory CouchDB** via [RockingChair](https://github.com/jweiss/rocking_chair)
- **Zero driver dependency** — your app brings its own CouchDB client

The adapter pattern is a work in progress. Today the default adapter is CouchRest; the architecture supports dropping in CouchBase or any CouchDB-compatible client.

## Dependencies

| Gem | Version | Notes |
|-----|---------|-------|
| activemodel | >= 6.0 | Validations, callbacks, dirty tracking |
| activesupport | >= 6.0 | Inflections, callbacks, concern |

No CouchDB driver bundled. Add `couchrest` or `couchbase` to your Gemfile.

## Testing

```bash
bundle exec rspec
```

Uses [RockingChair](https://github.com/jweiss/rocking_chair) — an in-memory CouchDB-compatible server for tests. No external CouchDB required.

## License

BSD 2-Clause — see [LICENSE.txt](LICENSE.txt)
