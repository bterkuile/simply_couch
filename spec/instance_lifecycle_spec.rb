require 'spec_helper'

describe 'Instance lifecycle' do
  context 'design documents' do
    let(:db_url) { 'http://127.0.0.1:5984/simply_couch_test' }

    it 'deletes all' do
      expect(SimplyCouch::Model.delete_all_design_documents(db_url)).to eq 0
      user = User.create
      Post.create(user: user)
      user.posts
      expect(SimplyCouch::Model.delete_all_design_documents(db_url)).to eq 1
    end

    it 'compacts all' do
      expect(SimplyCouch::Model.compact_all_design_documents(db_url)).to eq 0
      user = User.create
      Post.create(user: user)
      user.posts
      expect(SimplyCouch::Model.compact_all_design_documents(db_url)).to eq 1
    end
  end

  context 'when creating instances' do
    it 'populates the attributes' do
      user = User.create(title: 'Mr.', name: 'Host Master')
      expect(user.title).to eq 'Mr.'
      expect(user.name).to eq 'Host Master'
    end

    it 'saves the instance' do
      user = User.create(title: 'Mr.')
      expect(user).not_to be_new_record
    end

    context 'with a bang' do
      it 'does not raise an exception when saving succeeded' do
        expect { User.create!(title: 'Mr.') }.not_to raise_error
      end

      it 'saves the user' do
        user = User.create!(title: 'Mr.')
        expect(user).not_to be_new_record
      end

      it 'raises an error when the validations failed' do
        expect { User.create!(title: nil) }.to raise_error(CouchPotato::Database::ValidationsFailedError)
      end
    end

    context 'with a block' do
      it 'calls the block with the record' do
        user = User.create do |u|
          u.title = 'Mr.'
        end
        expect(user.title).to eq 'Mr.'
      end

      it 'saves the record' do
        user = User.create do |u|
          u.title = 'Mr.'
        end
        expect(user).not_to be_new_record
      end

      it 'assigns attributes via the hash' do
        user = User.create(title: 'Mr.') do |u|
          u.name = 'Host Master'
        end
        expect(user.title).to eq 'Mr.'
        expect(user.name).to eq 'Host Master'
      end
    end
  end

  context 'when saving an instance' do
    it 'saves the instance' do
      user = User.new(title: 'Mr.')
      expect(user).to be_new_record
      user.save
      expect(user).not_to be_new_record
    end

    context 'when using save!' do
      it 'raises an exception when a validation is not fulfilled' do
        user = User.new
        expect { user.save! }.to raise_error(CouchPotato::Database::ValidationsFailedError)
      end
    end

    context 'when using save(false)' do
      it 'does not run the validations' do
        user = User.new
        user.save(false)
        expect(user).not_to be_new
        expect(user).not_to be_dirty
      end
    end
  end

  context 'when destroying an instance' do
    it 'removes the instance' do
      user = User.create(title: 'Mr')
      expect { user.destroy }.to change { User.find(:all).size }.by(-1)
    end

    it 'returns the frozen instance' do
      user = User.create(title: 'Mr')
      expect(user.destroy).to eq user
    end
  end

  context 'when updating attributes' do
    it 'merges in the updated attributes' do
      user = User.create(title: 'Mr.')
      user.update_attributes(title: 'Mrs.')
      expect(user.title).to eq 'Mrs.'
    end

    it 'saves the instance' do
      user = User.create(title: 'Mr.')
      user.update_attributes(title: 'Mrs.')
      expect(user).not_to be_dirty
    end
  end

  context 'when counting' do
    context 'when counting all' do
      it 'returns the number of objects in the database' do
        CountMe.create(title: 'Mr.')
        CountMe.create(title: 'Mrs.')
        expect(CountMe.find(:all).size).to eq 2
        expect(CountMe.count).to eq 2
      end

      it 'only counts the correct class' do
        CountMe.create(title: 'Mr.')
        DontCountMe.create(title: 'Foo')
        expect(CountMe.find(:all).size).to eq 1
        expect(CountMe.count).to eq 1
      end
    end

    context 'when counting by prefix' do
      it 'returns the number of matching objects' do
        CountMe.create(title: 'Mr.')
        CountMe.create(title: 'Mrs.')
        expect(CountMe.find_all_by_title('Mr.').size).to eq 1
        expect(CountMe.count_by_title('Mr.')).to eq 1
      end

      it 'only counts the correct class' do
        CountMe.create(title: 'Mr.')
        DontCountMe.create(title: 'Mr.')
        expect(CountMe.find_all_by_title('Mr.').size).to eq 1
        expect(CountMe.count_by_title('Mr.')).to eq 1
      end
    end
  end

  context 'when reloading an instance' do
    it 'reloads new attributes from the database' do
      user = User.create(title: 'Mr.', name: 'Host Master')
      user2 = User.find(user.id)
      user2.update_attributes(title: 'Mrs.', name: 'Hostess Masteress')
      user.reload
      expect(user.title).to eq 'Mrs.'
      expect(user.name).to eq 'Hostess Masteress'
    end

    it 'removes attributes that are no longer in the database' do
      user = User.create(title: 'Mr.', name: 'Host Master')
      expect(user.name).not_to be_nil
      same_user_in_different_thread = User.find(user.id)
      same_user_in_different_thread.name = nil
      same_user_in_different_thread.save!
      expect(user.reload.name).to be_nil
    end

    it 'also removes foreign key attributes that are no longer in the database' do
      user = User.create(title: 'Mr.', name: 'Host Master')
      post = Post.create(user: user)
      expect(post.user_id).not_to be_nil
      same_post_in_different_thread = Post.find(post.id)
      same_post_in_different_thread.user = nil
      same_post_in_different_thread.save!
      expect(post.reload.user_id).to be_nil
    end

    it 'is not dirty after reloading' do
      user = User.create(title: 'Mr.', name: 'Host Master')
      user2 = User.find(user.id)
      user2.update_attributes(title: 'Mrs.', name: 'Hostess Masteress')
      user.reload
      expect(user).not_to be_dirty
    end

    it 'ensures that association caches for has_many are cleared' do
      user = User.create(title: 'Mr.', name: 'Host Master')
      post = Post.create(user: user)
      expect(user.posts.size).to eq 1
      expect(user.instance_variable_get('@posts')).not_to be_nil
      user.reload
      expect(user.instance_variable_get('@posts')).to be_nil
      expect(user.posts.first).not_to be_nil
    end

    it 'ensures that association caches for belongs_to are cleared' do
      user = User.create(title: 'Mr.', name: 'Host Master')
      post = Post.create(user: user)
      post.user
      expect(post.instance_variable_get('@user')).not_to be_nil
      post.reload
      expect(post.instance_variable_get('@user')).to be_nil
      expect(post.user).not_to be_nil
    end

    it 'updates the revision' do
      user = User.create(title: 'Mr.', name: 'Host Master')
      user2 = User.find(user.id)
      user2.update_attributes(title: 'Mrs.', name: 'Hostess Masteress')
      user.reload
      expect(user._rev).to eq user2._rev
    end
  end
end
