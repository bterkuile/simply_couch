require 'spec_helper'

describe "Embedding" do
  context "initialized comments" do
    before do
      @post = Post.new
      @post.embedded_comments = [
        { 'ruby_class' => 'EmbeddedComment', 'body' => 'body1' },
        { 'ruby_class' => 'EmbeddedComment', 'body' => 'body2' }
      ]
      @post.save
    end

    it "returns a valid size" do
      expect(@post.embedded_comments.size).to eq 2
      post_reloaded = Post.find(@post.id)
      expect(post_reloaded.embedded_comments.size).to eq 2
    end

    it "deletes comment using object" do
      @post.remove_embedded_comment(@post.embedded_comments.first)
      expect(@post.embedded_comments.size).to eq 1
      post_reloaded = Post.find(@post.id)
      expect(post_reloaded.embedded_comments.size).to eq 1
    end

    it "gets all embedded using .all" do
      expect(EmbeddedComment.all.size).to eq 2
    end

    it "gets embedded object, not a hash" do
      expect(EmbeddedComment.all.first).to be_a EmbeddedComment
    end

    it "has a parent_object when loaded through all" do
      expect(EmbeddedComment.all.first.parent_object).to eq @post
    end

    it "saves an instance" do
      comment = @post.embedded_comments.first
      comment.body = 'body-changed'
      comment.save
      comment_reloaded = Post.find(@post.id).embedded_comments.first
      expect(comment_reloaded.body).to eq 'body-changed'
    end

    it "changes attribute when not loaded through parent object" do
      embedded_comments = EmbeddedComment.all
      embedded_comment = embedded_comments.first
      embedded_comment.body = 'newbody'
      embedded_comment.save
      embedded_comments_reloaded = EmbeddedComment.all
      expect(embedded_comments_reloaded.map(&:body)).to include('newbody')
    end

    it "changes attribute when saved through parent object" do
      embedded_comments = EmbeddedComment.all
      embedded_comment = embedded_comments.first
      embedded_comment.body = 'newbody'
      embedded_comment.parent_object.is_dirty
      embedded_comment.parent_object.save
      embedded_comments_reloaded = EmbeddedComment.all
      expect(embedded_comments_reloaded.map(&:body)).to include('newbody')
    end

    it "counts embedded objects" do
      expect(EmbeddedComment.count).to eq 2
    end
  end

  context "creation of comment" do
    before do
      @post = Post.new
      @post.save
    end

    it "does not save when no parent is present" do
      comment = EmbeddedComment.new(body: 'no parent')
      expect(comment.save).to be false
      expect(comment.errors[:post]).to include('no_parent')
    end

    it "saves when initialized with parent relation name" do
      comment = EmbeddedComment.new(body: 'no parent', post: @post)
      expect(comment.save).to be true
      expect(comment.post).to eq @post
      expect(comment.parent_object).to eq @post
      expect(@post.embedded_comments).to include(comment)
      reloaded_post = Post.find(@post.id)
      expect(reloaded_post.embedded_comments).to include(comment)
    end

    it "saves when initialized with parent_object" do
      comment = EmbeddedComment.new(body: 'no parent', parent_object: @post)
      expect(comment.save).to be true
      expect(comment.post).to eq @post
      expect(comment.parent_object).to eq @post
      expect(@post.embedded_comments).to include(comment)
      expect(comment.save).to be true
      reloaded_post = Post.find(@post.id)
      expect(reloaded_post.embedded_comments).to include(comment)
    end

    it "saves when parent object is assigned later with relation name" do
      comment = EmbeddedComment.new(body: 'no parent')
      comment.post = @post
      expect(comment.save).to be true
      expect(comment.post).to eq @post
      expect(comment.parent_object).to eq @post
      expect(@post.embedded_comments).to include(comment)
      reloaded_post = Post.find(@post.id)
      expect(reloaded_post.embedded_comments).to include(comment)
    end

    it "saves when parent object is assigned later with parent_object" do
      comment = EmbeddedComment.new(body: 'no parent')
      comment.parent_object = @post
      expect(comment.save).to be true
      expect(comment.post).to eq @post
      expect(comment.parent_object).to eq @post
      expect(@post.embedded_comments).to include(comment)
      reloaded_post = Post.find(@post.id)
      expect(reloaded_post.embedded_comments).to include(comment)
    end
  end

  context "belongs to strict_post" do
    before do
      @user = User.create(name: 'embedding user')
      @strict_post = StrictPost.create(user: @user)
      @post = Post.new
      @post.embedded_comments = [
        { 'ruby_class' => 'EmbeddedComment', 'body' => 'body1' },
        { 'ruby_class' => 'EmbeddedComment', 'body' => 'body2' }
      ]
      @post.save
    end

    it "adds embedded comments to strict_post" do
      expect(@strict_post.save).to be true
      @post.embedded_comments.each { |ec| ec.strict_post = @strict_post; ec.save }
      strict_post_reloaded = StrictPost.find(@strict_post.id)
      expect(strict_post_reloaded.embedded_comments.size).to eq @post.embedded_comments.size
    end

    it "has strict_post as association" do
      expect(@strict_post.save).to be true
      @post.embedded_comments.each { |ec| ec.strict_post = @strict_post; ec.save }
      post_reloaded = Post.find(@post.id)
      comment_reloaded = post_reloaded.embedded_comments.first
      expect(comment_reloaded.strict_post).to eq @strict_post
    end

    it "has parent object when queried through relation" do
      expect(@strict_post.save).to be true
      @post.embedded_comments.each { |ec| ec.strict_post = @strict_post; ec.save }
      strict_post_reloaded = StrictPost.find(@strict_post.id)
      expect(strict_post_reloaded.embedded_comments.first).to eq @post.embedded_comments.first
      expect(strict_post_reloaded.embedded_comments.first.post).to eq @post
    end

    it "has actual object same as in parent object" do
      expect(@strict_post.save).to be true
      @post.embedded_comments.each { |ec| ec.strict_post = @strict_post; ec.save }
      strict_post_reloaded = StrictPost.find(@strict_post.id)
      embedded_comment = strict_post_reloaded.embedded_comments.first
      expect(embedded_comment.parent_object.embedded_comments.map(&:object_id)).to include(embedded_comment.object_id)
    end
  end
end
