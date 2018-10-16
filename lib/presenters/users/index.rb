class ApplicationPresenter
  def h
    self.class.h
  end

  class << self
    def h
      ::Draper::Decorator.h
    end
  end
end

module Presenters
  module Users
    class DividingUserPair < ::ApplicationPresenter
      attr_accessor :user_pair, :url, :label

      def initialize(user_pair:, current_page_string:, index:)
        self.user_pair = user_pair

        first_user = user_pair.first
        last_user = user_pair.second

        self.label, self.url =
            if first_user == last_user
              [
                  first_user.name,
                  h.user_path(first_user)
              ]
            else
              [
                  "#{first_user.name} - #{last_user.name}",
                  h.users_path(page: "#{current_page_string}-#{index}")
              ]
            end
      end

      def ==(other)
        return false unless other.is_a?(DividingUserPair)

        user_pair.first == other.user_pair.first &&
            user_pair.second == other.user_pair.second
      end

      private

      def label_and_url
        first_user = user_pair.first
        last_user = user_pair.second

        if first_user == last_user
          [
              first_user.name,
              h.user_path(first_user)
          ]
        else
          [
              "#{first_user.name} - #{last_user.name}",
              h.users_path(page: "#{current_page_string}-#{index}")
          ]
        end
      end
    end

    class Index < ::ApplicationPresenter
      MAX_LINKS_PER_PAGE = 50

      attr_accessor :current_page, :dividing_user_pairs

      def initialize(current_page_string:)
        dividing_chars = current_page_string.split('-')

        # security
        dividing_chars.each do |dividing_char|
          raise 'unexpected: not alphanumeric' unless alphanumeric?(dividing_char)
        end

        first_letter = dividing_chars.first
        users_within_current_page_scope = User.where('first_name LIKE ?', "#{first_letter}%").order('first_name asc')
        users_starting_with_letter_count = users_within_current_page_scope.count

        sum_result = dividing_chars.each_with_index.map do |dividing_char, index|
          # skip the first letter
          next 0 if index == 0

          previous_level_bucket_size = bucket_size_at_depth(users_starting_with_letter_count, index - 1)
          previous_level_bucket_size * dividing_char.to_i
        end
        start_index = sum_result.sum

        ##########################################G#################
        # ok, so now we want V users 4200-4219, 4200-4239, etc
        ###########################################################
        depth = dividing_chars.length - 1
        bucket_size = bucket_size_at_depth(users_starting_with_letter_count, depth)

        self.dividing_user_pairs =
            # if bucket_size > 0



            # want to get the "dividing names", i.e. every num_users / 150, create a new divider, for total of 150 dividers
            #
            # select the Nth row
            # https://stackoverflow.com/questions/16568/how-to-select-the-nth-row-in-a-sql-database-table
            #
            # Note: this does MAX_LINKS_PER_PAGE * 2 queries... I'm sure there's a better way to do this

            # TODO: MAX_LINKS_PER_PAGE is going to be overkill, too many for some pages
            #
            MAX_LINKS_PER_PAGE.times.map do |index|
              user_pair = dividing_users(users_within_current_page_scope, start_index, bucket_size, index)
              DividingUserPair.new(user_pair: user_pair, current_page_string: current_page_string, index: index)
            end.uniq { |pair| pair.user_pair }

              # uniq = dirty hack to remove dupes
            # else
            #   users = users_within_current_page_scope.limit(bucket_size).offset(start_index)
            #   users.map do |user|
            #     DividingUserPair(user_pair: [user, user], current_page_string: '_', index: '_')
            #   end
            # end

      end

      private


      def dividing_users(users_within_current_page_scope, start_index, bucket_size, index)
        # if bucket_size is 20, then this should grab user 4200, 4220, etc
        first_user_offset = start_index + bucket_size * (index.to_i - 1)
        # if bucket_size is 20, then this should grab user 4219, 4239, etc
        second_user_offset = first_user_offset + bucket_size - 1

        [
            users_within_current_page_scope.limit(1).offset(first_user_offset).first,
            users_within_current_page_scope.limit(1).offset(second_user_offset).first
        ]
      end

      def bucket_size_at_depth(users_starting_with_letter_count, depth)
        [
            # depth + 1, since depth 0 has users_starting_with_letter_count / MAX_LINKS_PER_PAGE buckets
            users_starting_with_letter_count / MAX_LINKS_PER_PAGE**(depth + 1),

            # should be at least 1, for the case where there are more names than buckets
            # TODO: there's probably something more elegant here
            1
        ].max
      end

      def alphanumeric?(string)
        chars = ('a'..'z').to_a + ('A'..'Z').to_a + (0..9).to_a.map(&:to_s)
        string.chars.detect { |char| !chars.include?(char) }.nil?
      end
    end
  end
end
