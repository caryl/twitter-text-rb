class String
  # Helper function to count the character length by first converting to an
  # array.  This is needed because with unicode strings, the return value
  # of length may be incorrect
  def char_length
    if respond_to? :codepoints
      length
    else
      chars.kind_of?(Enumerable) ? chars.to_a.size : chars.size
    end
  end

  # Helper function to convert this string into an array of unicode characters.
  def to_char_a
    @to_char_a ||= if chars.kind_of?(Enumerable)
      chars.to_a
    else
      char_array = []
      0.upto(char_length - 1) { |i| char_array << [chars.slice(i)].pack('U') }
      char_array
    end
  end
end

# Helper functions to return character offsets instead of byte offsets.
class MatchData
  def char_begin(n)
    if string.respond_to? :codepoints
      self.begin(n)
    else
      string[0, self.begin(n)].char_length
    end
  end

  def char_end(n)
    if string.respond_to? :codepoints
      self.end(n)
    else
      string[0, self.end(n)].char_length
    end
  end
end

module Twitter
  # A module for including Tweet parsing in a class. This module provides function for the extraction and processing
  # of usernames, lists, URLs and hashtags.
  module Extractor extend self

    # Extracts a list of all usernames mentioned in the Tweet <tt>text</tt>. If the
    # <tt>text</tt> is <tt>nil</tt> or contains no username mentions an empty array
    # will be returned.
    #
    # If a block is given then it will be called for each username.
    def extract_mentioned_screen_names(text) # :yields: username
      screen_names_only = extract_mentioned_screen_names_with_indices(text).map{|mention| mention[:screen_name] }
      screen_names_only.each{|mention| yield mention } if block_given?
      screen_names_only
    end

    # Extracts a list of all usersnames mentioned in the Tweet <tt>text</tt>
    # along with the indices for where the mention ocurred.  If the
    # <tt>text</tt> is nil or contains no username mentions, an empty array
    # will be returned.
    #
    # If a block is given, then it will be called with each username, the start
    # index, and the end index in the <tt>text</tt>.
    def extract_mentioned_screen_names_with_indices(text) # :yields: username, start, end
      return [] unless text

      possible_screen_names = []
      text.to_s.scan(Twitter::Regex[:extract_mentions]) do |before, sn, after|
        extract_mentions_match_data = $~
        unless after =~ Twitter::Regex[:end_screen_name_match]
          start_position = extract_mentions_match_data.char_begin(2) - 1
          end_position = extract_mentions_match_data.char_end(2)
          possible_screen_names << {
            :screen_name => sn,
            :indices => [start_position, end_position]
          }
        end
      end
      if block_given?
        possible_screen_names.each do |mention|
          yield mention[:screen_name], mention[:indices].first, mention[:indices].last
        end
      end
      possible_screen_names
    end

    # Extracts the username username replied to in the Tweet <tt>text</tt>. If the
    # <tt>text</tt> is <tt>nil</tt> or is not a reply nil will be returned.
    #
    # If a block is given then it will be called with the username replied to (if any)
    def extract_reply_screen_name(text) # :yields: username
      return nil unless text

      possible_screen_name = text.match(Twitter::Regex[:extract_reply])
      return unless possible_screen_name.respond_to?(:captures)
      screen_name = possible_screen_name.captures.first
      yield screen_name if block_given?
      screen_name
    end

    # Extracts a list of all URLs included in the Tweet <tt>text</tt>. If the
    # <tt>text</tt> is <tt>nil</tt> or contains no URLs an empty array
    # will be returned.
    #
    # If a block is given then it will be called for each URL.
    def extract_urls(text) # :yields: url
      urls_only = extract_urls_with_indices(text).map{|url| url[:url] }
      urls_only.each{|url| yield url } if block_given?
      urls_only
    end

    # Extracts a list of all URLs included in the Tweet <tt>text</tt> along
    # with the indices. If the <tt>text</tt> is <tt>nil</tt> or contains no
    # URLs an empty array will be returned.
    #
    # If a block is given then it will be called for each URL.
    def extract_urls_with_indices(text) # :yields: url, start, end
      return [] unless text
      urls = []
      position = 0
      text.to_s.scan(Twitter::Regex[:valid_url]) do |all, before, url, protocol, domain, path, query|
        valid_url_match_data = $~
        if !protocol.blank?
          start_position = valid_url_match_data.char_begin(3)
          end_position = valid_url_match_data.char_end(3)
          urls << {
            :url => url,
            :indices => [start_position, end_position]
          }
        end
      end
      urls.each{|url| yield url[:url], url[:indices].first, url[:indices].last } if block_given?
      urls
    end

    # Extracts a list of all hashtags included in the Tweet <tt>text</tt>. If the
    # <tt>text</tt> is <tt>nil</tt> or contains no hashtags an empty array
    # will be returned. The array returned will not include the leading <tt>#</tt>
    # character.
    #
    # If a block is given then it will be called for each hashtag.
    def extract_hashtags(text) # :yields: hashtag_text
      hashtags_only = extract_hashtags_with_indices(text).map{|hash| hash[:hashtag] }
      hashtags_only.each{|hash| yield hash } if block_given?
      hashtags_only
    end

    # Extracts a list of all hashtags included in the Tweet <tt>text</tt>. If the
    # <tt>text</tt> is <tt>nil</tt> or contains no hashtags an empty array
    # will be returned. The array returned will not include the leading <tt>#</tt>
    # character.
    #
    # If a block is given then it will be called for each hashtag.
    def extract_hashtags_with_indices(text) # :yields: hashtag_text, start, end
      return [] unless text

      tags = []
      text.scan(Twitter::Regex[:auto_link_hashtags]) do |before, hash1, hash_text, hash2|
        start_position = $~.char_begin(2)
        end_position = $~.char_end(4)
        tags << {
          :hashtag => hash_text,
          :indices => [start_position, end_position]
        }
      end
      tags.each{|tag| yield tag[:hashtag], tag[:indices].first, tag[:indices].last } if block_given?
      tags
    end
  end
end
