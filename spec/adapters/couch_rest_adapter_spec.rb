require 'spec_helper'

# Resolve (and lazily require) the configured backend before referencing it.
SimplyCouch.adapter_class

# The default backend must satisfy the backend-neutral adapter contract.
RSpec.describe SimplyCouch::Adapters::CouchRest do
  it_behaves_like 'a simply_couch adapter'
end
