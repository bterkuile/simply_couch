require 'spec_helper'

describe 'has_one' do
  it 'adds a getter method' do
    expect(Instance.new).to respond_to(:identity)
  end

  it 'raises an error if another property with the same name already exists' do
    expect {
      class ::DoubleHasOneUser
        include SimplyCouch::Model
        property :user
        has_one :user
      end
    }.to raise_error RuntimeError
  end

  it 'fetches the object when invoking the getter' do
    instance = Instance.create
    identity = Identity.create(instance: instance)
    expect(instance.identity).to eq identity
  end

  it 'sets the parent object on the clients cache' do
    expect(Instance).not_to receive(:find)
    instance = Instance.create
    identity = Identity.create(instance: instance)
    expect(instance.identity.instance).to eq instance
  end

  it 'uses the correct view when handling inheritance' do
    problem = Problem.create
    big_problem = BigProblem.create
    issue = Issue.create(name: 'Thing', problem: problem)
    expect(problem.issue).to eq issue
    issue.update_attributes(problem_id: nil, big_problem_id: big_problem.id)
    expect(big_problem.issue).to eq issue
  end

  it 'verifies the given options for the accessor method' do
    instance = Instance.create
    expect { instance.identity(foo: :var) }.to raise_error ArgumentError
  end

  it 'verifies the given options for the association definition' do
    expect {
      User.instance_eval do
        has_one :foo, bar: :do
      end
    }.to raise_error ArgumentError
  end

  it 'stores the fetched object into the cache' do
    instance = Instance.create
    identity = Identity.create(instance: instance)
    instance.identity
    expect(instance.instance_variable_get('@identity')).to eq identity
  end

  it 'does not fetch from the database when object is in cache' do
    instance = Instance.create
    identity = Identity.create(instance: instance)
    instance.identity
    expect(SimplyCouch.database).not_to receive(:view)
    instance.identity
  end

  it 'updates the foreign object to have the owners id in the foreign key' do
    instance = Instance.create
    identity = Identity.create
    instance.identity = identity
    identity.reload
    expect(identity.instance_id).to eq instance.id
  end

  it 'updates the cache when setting' do
    instance = Instance.create
    identity = Identity.create
    instance.identity = identity
    expect(SimplyCouch).not_to receive(:database)
    expect(instance.identity).to eq identity
  end

  it 'sets the foreign key value to nil when assigning nil' do
    instance = Instance.create
    identity = Identity.create(instance: instance)
    instance.identity = nil
    identity = Identity.find(identity.id)
    expect(identity.instance_id).to be_nil
  end

  it 'checks the class' do
    instance = Instance.create
    expect { instance.identity = 'foo' }.to raise_error ArgumentError, /expected Identity got String/
  end

  it 'deletes the dependent objects when dependent is set to destroy' do
    identity = Identity.create
    mag = Magazine.create
    mag.identity = identity
    mag.identity = nil
    expect(Identity.find_by_id(identity.id)).to be_nil
  end

  it 'unsets the id on the foreign object when a new object is set' do
    instance = Instance.create
    identity = Identity.create(instance: instance)
    identity2 = Identity.create
    instance.identity = identity2
    identity = Identity.find(identity.id)
    expect(identity.instance_id).to be_nil
  end

  it 'deletes the foreign object when a new object is set and dependent is set to destroy' do
    identity = Identity.create
    identity2 = Identity.create
    mag = Magazine.create
    mag.identity = identity
    mag.identity = identity2
    expect(Identity.find_by_id(identity.id)).to be_nil
  end

  it 'deletes the foreign object when parent is destroyed and dependent is set to destroy' do
    identity = Identity.create
    mag = Magazine.create
    mag.identity = identity
    mag.destroy
    expect(Identity.find_by_id(identity.id)).to be_nil
  end

  it 'nullifies the foreign objects foreign key when parent is destroyed' do
    identity = Identity.create
    instance = Instance.create
    instance.identity = identity
    instance.destroy
    identity = Identity.find(identity.id)
    expect(identity.instance_id).to be_nil
  end
end
