# frozen_string_literal: true

module SimplyCouch
  # Reconstructs a stored JSON document (a plain Hash) back into its model
  # instance, independently of any database driver.
  #
  # simply_couch tags every persisted document with a "ruby_class" key (see
  # SimplyCouch::Model::Persistence::Json#to_hash), and every model defines
  # .json_create. Together they let an adapter rehydrate a model from a hash
  # without relying on a particular driver's JSON-decoding hook.
  #
  # The CouchRest adapter lets couchrest decode for it (it sets
  # JSON.create_id = 'ruby_class', so JSON.parse already returns model objects).
  # Adapters whose driver returns plain hashes (e.g. couchbase) call
  # DocumentCodec.from_hash to get the same result.
  module DocumentCodec
    module_function

    # hash -> model instance. Returns the input unchanged when it is nil or
    # carries no recognised ruby_class tag (so raw/system rows pass through).
    def from_hash(hash)
      return hash if hash.nil?
      klass_name = hash['ruby_class'] || hash[:ruby_class]
      return hash unless klass_name
      klass = constantize(klass_name)
      return hash unless klass.respond_to?(:json_create)
      klass.json_create(hash)
    end

    def constantize(name)
      Object.const_get(name)
    rescue NameError
      nil
    end
  end
end
