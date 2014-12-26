require 'spec_helper'

describe ProductHunt do

  TIMESTAMP_FORMAT = '%FT%T.%L%:z'
  DATESTAMP_FORMAT = '%F'

  before(:each) do
    @client = ProductHunt::Client.new(ENV['TOKEN'] || 'my-token')
  end

  describe 'API' do

    it 'requires a valid API token (eg. env TOKEN=mytoken bundle exec rake)' do
      ENV["TOKEN"].should_not be_nil
    end

    describe 'Posts' do

      it 'implements posts#index and yields the hunts for today' do
        stub_request(:get, "https://api.producthunt.com/v1/posts").
          to_return(lambda { |request|
            File.new("./spec/support/index_response.txt").read.
              gsub(/POST_TIMESTAMP/, (Time.now - 86400).strftime(TIMESTAMP_FORMAT)).
              gsub(/POST_DATESTAMP/, (Time.now - 86400).strftime(DATESTAMP_FORMAT))
          })

        posts = @client.posts
        expect(posts.size).to be > 0

        post = posts.first
        day = post.day

        expect(Time.now.to_date - day).to be <= 1 # either today's or yesterdays
      end

      it 'implements posts#index and yields the hunts for days_ago: 10' do
        stub_request(:get, "https://api.producthunt.com/v1/posts?days_ago=10").
          to_return(lambda { |request|
            File.new("./spec/support/index_with_10day_param_response.txt").read.
              gsub(/POST_TIMESTAMP/, (Time.now - 10 * 86400).strftime(TIMESTAMP_FORMAT)).
              gsub(/POST_DATESTAMP/, (Time.now - 10 * 86400).strftime(DATESTAMP_FORMAT))
          })

        posts = @client.posts(days_ago: 10)
        expect(posts.size).to be > 0

        post = posts.first
        day = post.day

        expect(Time.now.to_date - day).to be >= 10 # at least 10 day old and
        expect(Time.now.to_date - day).to be <= 11 # at most 11 days old
      end

      describe 'by id' do

        before(:each) do
          stub_request(:get, "https://api.producthunt.com/v1/posts/3372").
            to_return(File.new("./spec/support/get_post.txt"))
          @post = @client.post(3372)
        end

        it 'implements posts#show and yields the name of the post' do
          @post['name'].should == 'namevine'
        end

        describe 'Votes' do

          before(:each) do
            stub_request(:get, "https://api.producthunt.com/v1/posts/3372").
            to_return(File.new("./spec/support/get_post.txt"))
            @post = @client.post(3372)
          end

          it 'implements votes#index and yields the first voter' do
            stub_request(:get, "https://api.producthunt.com/v1/posts/3372/votes").
              to_return(File.new("./spec/support/get_post_votes.txt"))

            vote = @post.votes.first

            vote.should be_a(ProductHunt::Vote)
            vote['user']['username'].should == '1korda'
          end

          it 'implements votes#index with pagination' do
            stub_request(:get, "https://api.producthunt.com/v1/posts/3372/votes?per_page=1").
              to_return(File.new("./spec/support/get_post_votes_per_page.txt"))

            votes = @post.votes(per_page: 1)
            votes.size.should be(1)

            stub_request(:get, "https://api.producthunt.com/v1/posts/3372/votes?older=508515&per_page=1").
              to_return(File.new("./spec/support/get_post_votes_per_page_older.txt"))

            votes = @post.votes(per_page: 1, older: votes.first['id'])
            votes.size.should be(1)
            votes.first['user']['username'].should == 'mikejarema'
          end
        end

        describe 'Comments' do
          it 'implements comments#index and yields the first voter' do
            stub_request(:get, "https://api.producthunt.com/v1/posts/3372/comments?order=asc").
              to_return(File.new("./spec/support/comments_index.txt"))

            comment = @post.comments(order: 'asc').first

            comment.should be_a(ProductHunt::Comment)
            comment['user']['username'].should == 'andreasklinger'
          end

          it 'implements comments#index with pagination' do
            stub_request(:get, "https://api.producthunt.com/v1/posts/3372/comments?order=asc&per_page=1").
              to_return(File.new("./spec/support/comments_index_per_page.txt"))

            comments = @post.comments(per_page: 1, order: 'asc')
            comments.size.should be(1)

            stub_request(:get, "https://api.producthunt.com/v1/posts/3372/comments?per_page=1&order=asc&newer=11378").
              to_return(File.new("./spec/support/comments_index_per_page_newer.txt"))

            comments = @post.comments(per_page: 1, order: 'asc', newer: comments.first['id'])
            comments.size.should be(1)
            comments.first['user']['username'].should == 'dshan'
          end
        end

      end

    end

    describe 'Users' do

      it 'implements users#show and yields the details of a specific user' do
        stub_request(:get, "https://api.producthunt.com/v1/users/rrhoover").
          to_return(File.new("./spec/support/get_user.txt"))

        user = @client.user('rrhoover')

        user['name'].should == 'Ryan Hoover'
        user['id'].should == 2
      end

    end

  end

end
