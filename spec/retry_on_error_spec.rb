require 'spec_helper'

describe 'Retry on error' do
  it 'retries the save on connection error' do
    user = User.create(name: 'Mickey Mouse', title: 'Dr.', homepage: 'www.gmx.de')
    error = Errno::ECONNREFUSED.new('Connection refused - connect(2)')
    expect(SimplyCouch.database).to receive(:save_document).once.and_raise(error).ordered
    expect(SimplyCouch.database).to receive(:save_document).once.and_return(true).ordered

    user.name = 'bert'
    expect(user.save).to be true
  end

  it 'retries the save! on connection error' do
    error = Errno::ECONNREFUSED.new('Connection refused - connect(2)')
    expect(SimplyCouch.database).to receive(:save_document).once.and_raise(error).ordered
    expect(SimplyCouch.database).to receive(:save_document).once.and_return(true).ordered

    user = User.create(name: 'Mickey Mouse', title: 'Dr.', homepage: 'www.gmx.de')
    expect(user).to be_truthy
  end

  it 're-raises the error if retried several times' do
    error = Errno::ECONNREFUSED.new('Connection refused - connect(2)')
    expect(SimplyCouch.database).to receive(:save_document).exactly(3).times.and_raise(error)

    expect {
      User.create(name: 'Mickey Mouse', title: 'Dr.', homepage: 'www.gmx.de')
    }.to raise_error(Errno::ECONNREFUSED)
  end
end
