require 'spec_helper'

def recreate_db!
  server = CouchRest.new(COUCHDB_URL)
  begin
    server.database(TEST_DB).delete!
  rescue StandardError
    # already gone
  end
  begin
    server.create_db(TEST_DB)
  rescue CouchRest::PreconditionFailed, CouchRest::NotFound
    # already exists
  end
  SimplyCouch::Model::View::ViewQuery.clear_cache
end

RSpec.describe 'SoftDeletable' do
  context 'when using soft deletable' do
    it 'knows when it is enabled' do
      expect(Hemorrhoid.soft_deleting_enabled?).to be true
      expect(User.soft_deleting_enabled?).to be false
    end

    it 'defines a :deleted_at attribute' do
      h = Hemorrhoid.new
      expect(h).to respond_to(:deleted_at)
      expect(h).to respond_to(:deleted_at=)
      expect(Hemorrhoid.soft_delete_attribute).to eq :deleted_at
    end

    it 'defines hard delete methods' do
      h = Hemorrhoid.new
      expect(h).to respond_to(:destroy!)
      expect(h).to respond_to(:delete!)
    end

    context 'when deleting' do
      before do
        @user = User.new(:name => 'BigT', :title => 'Dr.')
        @user.save!
        @hemorrhoid = Hemorrhoid.new
        @hemorrhoid.user = @user
        @hemorrhoid.save!
      end

      it 'does not delete the object but populates the soft_delete_attribute' do
        now = Time.now
        allow(Time).to receive(:now).and_return(now)
        expect(@hemorrhoid.deleted_at).to be_nil
        expect(@hemorrhoid.delete).to be_truthy
        expect(@hemorrhoid.deleted_at).to eq now
      end

      it 'survives reloads with the new attribute' do
        expect(@hemorrhoid.deleted_at).to be_nil
        expect(@hemorrhoid.delete).to be_truthy
        @hemorrhoid.reload
        expect(@hemorrhoid.deleted_at).not_to be_nil
      end

      it 'knows when it is deleted' do
        expect(@hemorrhoid.deleted?).to be false
        @hemorrhoid.delete
        expect(@hemorrhoid.deleted?).to be true
      end

      it 'does not consider objects without soft-deleted as deleted' do
        expect(@user.deleted?).to be false
        @user.delete
        expect(@user.deleted?).to be false
      end

      it 'does not delete in DB' do
        expect(SimplyCouch.database).not_to receive(:destroy_document)
        @hemorrhoid.destroy
      end

      it 'really deletes with callbacks' do
        expect(SimplyCouch.database).to receive(:destroy_document).with(@hemorrhoid, true)
        @hemorrhoid.destroy!
      end

      it 'really deletes without callbacks if the object was soft-deleted before' do
        expect(SimplyCouch.database).to receive(:destroy_document).with(@hemorrhoid, false)
        @hemorrhoid.destroy
        @hemorrhoid.destroy!
      end

      context 'callbacks' do
        it 'still fires the callbacks' do
          @hemorrhoid = Hemorrhoid.create
          $before = nil
          $after = nil
          def @hemorrhoid.before_destroy_callback
            $before = 'now'
          end

          def @hemorrhoid.after_destroy_callback
            $after = 'now'
          end

          @hemorrhoid.destroy

          expect($before).not_to be_nil
          expect($after).not_to be_nil
        end

        it 'does not fire the callbacks on the real destroy if the object is already deleted' do
          @hemorrhoid = Hemorrhoid.create
          def @hemorrhoid.before_destroy_callback
            raise "Callback called even though #{skip_callbacks.inspect}"
          end

          def @hemorrhoid.after_destroy_callback
            raise "Callback called even though #{skip_callbacks.inspect}"
          end

          def @hemorrhoid.deleted?
            true
          end

          expect { @hemorrhoid.destroy! }.not_to raise_error
        end

        it 'fires the callbacks on the real destroy if the object is not deleted' do
          @hemorrhoid = Hemorrhoid.create
          $before = nil
          $after = nil
          def @hemorrhoid.before_destroy_callback
            $before = 'now'
          end

          def @hemorrhoid.after_destroy_callback
            $after = 'now'
          end

          @hemorrhoid.destroy!

          expect($before).not_to be_nil
          expect($after).not_to be_nil
        end
      end

      context 'when handling the dependent objects' do
        before do
          @sub = SubHemorrhoid.new
          @sub.hemorrhoid = @hemorrhoid
          @sub.save!

          @easy_sub = EasySubHemorrhoid.new
          @easy_sub.hemorrhoid = @hemorrhoid
          @easy_sub.save!

          @rash = Rash.new
          @rash.hemorrhoid = @hemorrhoid
          @rash.save!

          @hemorrhoid.reload
        end

        it 'deletes them' do
          @hemorrhoid.delete
          @sub.reload
          expect(@sub.deleted?).to be true
          expect { EasySubHemorrhoid.find(@easy_sub.id, :with_deleted => true) }.to raise_error(SimplyCouch::RecordNotFound)
          @rash = Rash.find(@rash.id)
          expect(@rash.hemorrhoid_id).to be_nil
        end

        it 'really deletes them if the parent is really deleted' do
          @hemorrhoid.delete!
          expect { EasySubHemorrhoid.find(@sub.id, :with_deleted => true) }.to raise_error(SimplyCouch::RecordNotFound)

          expect { EasySubHemorrhoid.find(@easy_sub.id, :with_deleted => true) }.to raise_error(SimplyCouch::RecordNotFound)

          @rash = Rash.find(@rash.id)
          expect(@rash.hemorrhoid_id).to be_nil
        end

        it 'nullifies dependents if they are soft-deletable and deleted' do
          small_rash = SmallRash.create(:hemorrhoid => @hemorrhoid)
          @hemorrhoid.reload
          @hemorrhoid.destroy
          expect(@hemorrhoid.deleted?).to be true
          small_rash = SmallRash.find(small_rash.id)
          expect(small_rash.hemorrhoid_id).to be_nil
        end

        it 'does not nullify dependents if they are soft-deletable and not deleted' do
          small_rash = SmallRash.create(:hemorrhoid => @hemorrhoid)
          @hemorrhoid.reload
          expect(@hemorrhoid.deleted?).to be false
          small_rash = SmallRash.find(small_rash.id)
          expect(small_rash.hemorrhoid_id).not_to be_nil
          expect(small_rash.hemorrhoid_id).to eq @hemorrhoid.id
        end
      end
    end

    context 'when loading' do
      before do
        @user = User.new(:name => 'BigT', :title => 'Dr.')
        @user.save!
        @hemorrhoid = Hemorrhoid.new
        @hemorrhoid.user = @user
        @hemorrhoid.save!
      end

      context 'by id' do
        it 'is not found by default' do
          @hemorrhoid.destroy
          expect { Hemorrhoid.find(@hemorrhoid.id) }.to raise_error(SimplyCouch::RecordNotFound)
        end

        it 'is found if supplied with :with_deleted' do
          @hemorrhoid.destroy

          expect(Hemorrhoid.find(@hemorrhoid.id, :with_deleted => true)).not_to be_nil
        end

        it 'is not found if it is really gone' do
          old_id = @hemorrhoid.id
          @hemorrhoid.destroy!

          expect { Hemorrhoid.find(old_id) }.to raise_error(SimplyCouch::RecordNotFound)
        end

        it 'always reloads' do
          @hemorrhoid.destroy
          expect { @hemorrhoid.reload }.not_to raise_error
          expect(@hemorrhoid.deleted_at).not_to be_nil
        end
      end

      context 'all' do
        before do
          recreate_db!
          @hemorrhoid = Hemorrhoid.create
          expect(@hemorrhoid.destroy).to be_truthy
          expect(@hemorrhoid.reload.deleted?).to be true
        end

        it 'does not load deleted' do
          expect(Hemorrhoid.find(:all)).to eq []
          expect(Hemorrhoid.find(:all, :with_deleted => false)).to eq []
        end

        it 'loads non-deleted' do
          hemorrhoid = Hemorrhoid.create
          expect(Hemorrhoid.find(:all)).not_to eq []
          expect(Hemorrhoid.find(:all, :with_deleted => false)).not_to eq []
        end

        it 'loads deleted if asked to' do
          expect(Hemorrhoid.find(:all, :with_deleted => true).map(&:id)).to eq [@hemorrhoid.id]
        end
      end

      context 'first' do
        before do
          recreate_db!
          @hemorrhoid = Hemorrhoid.create
          expect(@hemorrhoid.destroy).to be_truthy
          expect(@hemorrhoid.reload.deleted?).to be true
        end

        it 'does not load deleted' do
          expect(Hemorrhoid.find(:first)).to be_nil
          expect(Hemorrhoid.find(:first, :with_deleted => false)).to be_nil
        end

        it 'loads non-deleted' do
          hemorrhoid = Hemorrhoid.create
          expect(Hemorrhoid.find(:first)).not_to be_nil
          expect(Hemorrhoid.find(:first)).to be_a(Hemorrhoid)
          expect(Hemorrhoid.find(:first, :with_deleted => false)).not_to be_nil
          expect(Hemorrhoid.find(:first, :with_deleted => false)).to be_a(Hemorrhoid)
        end

        it 'loads deleted if asked to' do
          expect(Hemorrhoid.find(:first, :with_deleted => true)).to eq @hemorrhoid
        end
      end

      context 'find_by and find_all_by' do
        before do
          recreate_db!
          @hemorrhoid = Hemorrhoid.create(:nickname => 'Claas', :size => 3)
          @hemorrhoid.destroy
        end

        context 'find_by' do
          it 'does not load deleted' do
            expect(Hemorrhoid.find_by_nickname('Claas')).to be_nil
            expect(Hemorrhoid.find_by_nickname('Claas', :with_deleted => false)).to be_nil

            expect(Hemorrhoid.find_by_nickname_and_size('Claas', 3)).to be_nil
            expect(Hemorrhoid.find_by_nickname_and_size('Claas', 3, :with_deleted => false)).to be_nil
          end

          it 'loads non-deleted' do
            hemorrhoid = Hemorrhoid.create(:nickname => 'OtherNick', :size => 3)
            expect(Hemorrhoid.find_by_nickname('OtherNick', :with_deleted => true).id).to eq hemorrhoid.id
            expect(Hemorrhoid.find_by_nickname('OtherNick').id).to eq hemorrhoid.id
          end

          it 'loads deleted if asked to' do
            expect(Hemorrhoid.find_by_nickname('Claas', :with_deleted => true)).not_to be_nil
            expect(Hemorrhoid.find_by_nickname('Claas', :with_deleted => true).id).to eq @hemorrhoid.id

            expect(Hemorrhoid.find_by_nickname_and_size('Claas', 3, :with_deleted => true)).not_to be_nil
            expect(Hemorrhoid.find_by_nickname_and_size('Claas', 3, :with_deleted => true).id).to eq @hemorrhoid.id
          end
        end

        context 'find_all_by' do
          it 'does not load deleted' do
            expect(Hemorrhoid.find_all_by_nickname('Claas')).to eq []
            expect(Hemorrhoid.find_all_by_nickname('Claas', :with_deleted => false)).to eq []

            expect(Hemorrhoid.find_all_by_nickname_and_size('Claas', 3)).to eq []
            expect(Hemorrhoid.find_all_by_nickname_and_size('Claas', 3, :with_deleted => false)).to eq []
          end

          it 'loads non-deleted' do
            hemorrhoid = Hemorrhoid.create(:nickname => 'Lampe', :size => 4)
            expect(Hemorrhoid.find_all_by_nickname('Lampe').map(&:id)).to eq [hemorrhoid.id]
          end

          it 'loads deleted if asked to' do
            expect(Hemorrhoid.find_all_by_nickname('Claas', :with_deleted => true).map(&:id)).to eq [@hemorrhoid.id]
            expect(Hemorrhoid.find_all_by_nickname_and_size('Claas', 3, :with_deleted => true).map(&:id)).to eq [@hemorrhoid.id]
          end
        end

        it 'reuses the same view - when find_all_by is called first' do
          expect(Hemorrhoid.find_all_by_nickname('Claas')).to eq []
          expect(Hemorrhoid.find_by_nickname('Claas')).to be_nil
        end

        it 'reuses the same view - when find_by is called first' do
          expect(Hemorrhoid.find_by_nickname('Claas')).to be_nil
          expect(Hemorrhoid.find_all_by_nickname('Claas')).to eq []
        end
      end

      context 'by relation' do
        before do
          @hemorrhoid.destroy
        end

        context 'has_many' do
          it 'does not load deleted by default' do
            expect(@user.hemorrhoids(:force_reload => true)).to eq []
          end

          it 'loads deleted if asked to' do
            expect(@user.hemorrhoids(:force_reload => true, :with_deleted => true).map(&:id)).to eq [@hemorrhoid.id]
          end
        end

        context 'has_many :through' do
          before do
            @user = User.create(:name => 'BigT', :title => 'Dr.')
            @pain = Pain.create

            @hemorrhoid = Hemorrhoid.new
            @hemorrhoid.user = @user
            @hemorrhoid.pain = @pain
            @hemorrhoid.save!

            @hemorrhoid.destroy
          end

          it 'does not load deleted by default' do
            expect(@user.pains).to eq []
          end

          it 'loads deleted if asked to' do
            expect(@user.pains(:with_deleted => true).map(&:id)).to eq [@pain.id]
          end
        end

        context 'has_one' do
          before do
            @spot = Spot.create

            @hemorrhoid = Hemorrhoid.new
            @hemorrhoid.spot = @spot
            @hemorrhoid.save!

            @hemorrhoid.destroy
          end

          it 'does not load deleted by default' do
            expect(@spot.hemorrhoid(:force_reload => true)).to be_nil
          end

          it 'loads deleted if asked to' do
            expect(@spot.hemorrhoid(:force_reload => true, :with_deleted => true).id).to eq @hemorrhoid.id
          end
        end

        context 'belongs_to' do
          before do
            @hemorrhoid = Hemorrhoid.new
            @hemorrhoid.save!

            @sub = SubHemorrhoid.new
            @sub.hemorrhoid = @hemorrhoid
            @sub.save!

            @hemorrhoid.destroy
          end

          it 'does not load deleted by default' do
            @sub.reload
            expect(@sub.hemorrhoid(:force_reload => true)).to be_nil
          end

          it 'loads deleted if asked to' do
            @sub.reload
            expect(@sub.hemorrhoid(:force_reload => true, :with_deleted => true).id).to eq @hemorrhoid.id
          end
        end
      end
    end

    context 'when counting' do
      before do
        @hemorrhoid = Hemorrhoid.create(:nickname => 'Claas')
        expect(@hemorrhoid.destroy).to be_truthy
        expect(@hemorrhoid.reload.deleted?).to be true
      end

      it 'does not count deleted' do
        expect(Hemorrhoid.count).to eq 0
        expect(Hemorrhoid.count(:with_deleted => false)).to eq 0
      end

      it 'counts non-deleted' do
        hemorrhoid = Hemorrhoid.create(:nickname => 'Claas')
        expect(Hemorrhoid.count).to eq 1
        expect(Hemorrhoid.count(:with_deleted => false)).to eq 1
      end

      it 'counts deleted if asked to' do
        expect(Hemorrhoid.count(:with_deleted => true)).to eq 1
      end

      context 'count_by' do
        it 'does not count deleted' do
          expect(Hemorrhoid.count_by_nickname('Claas')).to eq 0
          expect(Hemorrhoid.count_by_nickname('Claas', :with_deleted => false)).to eq 0
        end

        it 'counts deleted if asked to' do
          expect(Hemorrhoid.count_by_nickname('Claas', :with_deleted => true)).to eq 1
        end
      end
    end
  end
end
