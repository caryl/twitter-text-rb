module Twitter
  # A module for including Tweet auto-linking in a class. The primary use of
  #   this is for helpers/views so they can auto-link usernames, lists, hashtags
  #   and URLs.
  module Autolink extend self
    include ActionView::Helpers::TagHelper #tag_options needed by auto_link
    extend ActionView::Helpers::TagHelper
    # Default CSS class for auto-linked URLs
    DEFAULT_URL_CLASS = "tweet-url"
    # Default CSS class for auto-linked lists (along with the url class)
    DEFAULT_LIST_CLASS = "list-slug"
    # Default CSS class for auto-linked usernames (along with the url class)
    DEFAULT_USERNAME_CLASS = "username"
    # Default CSS class for auto-linked hashtags (along with the url class)
    DEFAULT_HASHTAG_CLASS = "hashtag"
    # Default target for auto-linked urls (nil will not add a target attribute)
    DEFAULT_TARGET = nil
    # HTML attribute for robot nofollow behavior (default)
    HTML_ATTR_NO_FOLLOW = " rel=\"nofollow\""

    HTML_ENTITIES = {
      '&' => '&amp;',
      '>' => '&gt;',
      '<' => '&lt;',
      '"' => '&quot;',
      "'" => '&#39;'
    }

    def html_escape(text)
      text && text.gsub(/[&"'><]/) do |character|
        HTML_ENTITIES[character]
      end
    end

    # Add <tt><a></a></tt> tags around the usernames, lists, hashtags and URLs
    #   in the provided <tt>text</tt>. The <tt><a></tt> tags can be controlled
    #   with the following entries in the <tt>options</tt> hash:
    #
    # <tt>:url_class</tt>::     class to add to all <tt><a></tt> tags
    # <tt>:list_class</tt>::    class to add to list <tt><a></tt> tags
    # <tt>:username_class</tt>::    class to add to username <tt><a></tt> tags
    # <tt>:hashtag_class</tt>::    class to add to hashtag <tt><a></tt> tags
    # <tt>:username_url_base</tt>::      the value for <tt>href</tt> attribute
    #   on username links. The <tt>@username</tt> (minus the <tt>@</tt>) will be
    #   appended at the end of this.
    # <tt>:list_url_base</tt>::      the value for <tt>href</tt> attribute on
    #   list links. The <tt>@username/list</tt> (minus the <tt>@</tt>) will be
    #   appended at the end of this.
    # <tt>:hashtag_url_base</tt>::      the value for <tt>href</tt> attribute on
    #   hashtag links. The <tt>#hashtag</tt> (minus the <tt>#</tt>) will be
    #   appended at the end of this.
    # <tt>:suppress_lists</tt>::    disable auto-linking to lists
    # <tt>:suppress_no_follow</tt>::   Do not add <tt>rel="nofollow"</tt> to
    #   auto-linked items
    # <tt>:target</tt>::   add <tt>target="window_name"</tt> to auto-linked
    #   items
    def auto_link(text, options = {}, href_options = {}, &blk)
      auto_link_usernames(
        auto_link_urls_custom(
          auto_link_hashtags(text, options),
          href_options),
        options, &blk)
    end

    # Add <tt><a></a></tt> tags around the usernames and lists in the provided
    #   <tt>text</tt>. The <tt><a></tt> tags can be controlled with the
    #   following entries in the <tt>options</tt> hash:
    #
    # <tt>:url_class</tt>::     class to add to all <tt><a></tt> tags
    # <tt>:list_class</tt>::    class to add to list <tt><a></tt> tags
    # <tt>:username_class</tt>::    class to add to username <tt><a></tt> tags
    # <tt>:username_url_base</tt>::      the value for <tt>href</tt> attribute
    #   on username links. The <tt>@username</tt> (minus the <tt>@</tt>) will be
    #   appended at the end of this.
    # <tt>:list_url_base</tt>::      the value for <tt>href</tt> attribute on
    #   list links. The <tt>@username/list</tt> (minus the <tt>@</tt>) will be
    #   appended at the end of this.
    # <tt>:suppress_lists</tt>::    disable auto-linking to lists
    # <tt>:suppress_no_follow</tt>::   Do not add <tt>rel="nofollow"</tt> to
    #   auto-linked items
    # <tt>:target</tt>::   add <tt>target="window_name"</tt> to auto-linked
    #   items
    def auto_link_usernames(text, options = {}) # :yields: list_or_username
      options = options.dup
      options[:url_class] ||= DEFAULT_URL_CLASS
      options[:username_class] ||= DEFAULT_USERNAME_CLASS
      options[:username_url_base] ||= "http://twitter.com/"
      # #options[:list_url_base] ||= "http://twitter.com/"
      options[:target] ||= DEFAULT_TARGET

      extra_html = HTML_ATTR_NO_FOLLOW unless options[:suppress_no_follow]
      new_text = ""

      # this -1 flag allows strings ending in ">" to work
      text.split(/[<>]/, -1).each_with_index do |chunk, index|
        if index != 0
          new_text << ((index % 2 == 0) ? ">" : "<")
        end

        if index % 4 != 0
          new_text << chunk
        else
          new_text << chunk.gsub(Twitter::Regex[:auto_link_usernames]) do
            before, at, user, after = $1, $2, $3, $'
            #如果不加block参数，就假设screen_name是存在的，auto_link之！
            #如果加block参数，block需返回两个元素的数组，前一个为user对象，后一个为link想要设置的title
            user_model, title = block_given? ? yield(user) : [true, user]

            if after !~ Twitter::Regex[:end_screen_name_match] && user_model
              # this is a screen name
              chunk = user
              "#{before}#{at}<a title=\"#{html_escape(title)}\" class=\"#{options[:url_class]} #{options[:username_class]}\" #{target_tag(options)}href=\"#{html_escape(options[:username_url_base])}#{html_escape(chunk)}\"#{extra_html}>#{html_escape(chunk)}</a>"
            else
              # Followed by something that means we don't autolink
              # block return false
              "#{before}#{at}#{user}"
            end
          end
          
        end
      end
      new_text
    end

    # Add <tt><a></a></tt> tags around the hashtags in the provided
    # <tt>text</tt>. The <tt><a></tt> tags can be controlled with the following
    # entries in the <tt>options</tt> hash:
    #
    # <tt>:url_class</tt>::     class to add to all <tt><a></tt> tags
    # <tt>:hashtag_class</tt>:: class to add to hashtag <tt><a></tt> tags
    # <tt>:hashtag_url_base</tt>::      the value for <tt>href</tt> attribute.
    #   The hashtag text (minus the <tt>#</tt>) will be appended at the end of
    #   this.
    # <tt>:suppress_no_follow</tt>::   Do not add <tt>rel="nofollow"</tt> to
    #   auto-linked items
    # <tt>:target</tt>::   add <tt>target="window_name"</tt> to auto-linked
    #   items
    def auto_link_hashtags(text, options = {})  # :yields: hashtag_text
      options = options.dup
      options[:url_class] ||= DEFAULT_URL_CLASS
      options[:hashtag_class] ||= DEFAULT_HASHTAG_CLASS
      options[:hashtag_url_base] ||= "http://twitter.com/search?q="
      options[:target] ||= DEFAULT_TARGET
      extra_html = HTML_ATTR_NO_FOLLOW unless options[:suppress_no_follow]

      text.gsub(Twitter::Regex[:auto_link_hashtags]) do
        before = $1
        hash_start = $2
        text = $3
        hash_end = $4
        text = yield(text) if block_given?
        "#{before}<a href=\"#{options[:hashtag_url_base]}#{CGI.escape(text)}\" title=\"#{html_escape(text)}\" #{target_tag(options)}class=\"#{options[:url_class]} #{options[:hashtag_class]}\"#{extra_html}>#{html_escape(hash_start)}#{html_escape(text)}#{html_escape(hash_end)}</a>"
      end
    end

    # Add <tt><a></a></tt> tags around the URLs in the provided <tt>text</tt>.
    # Any elements in the <tt>href_options</tt> hash will be converted to HTML
    # attributes and place in the <tt><a></tt> tag. Unless <tt>href_options</tt>
    # contains <tt>:suppress_no_follow</tt> the <tt>rel="nofollow"</tt>
    # attribute will be added.
    def auto_link_urls_custom(text, href_options = {})
      options = href_options.dup
      options[:rel] = "nofollow" unless options.delete(:suppress_no_follow)

      text.gsub(Twitter::Regex[:valid_url]) do
        all, before, url, protocol, domain, path, query_string = $1, $2, $3, $4, $5, $6, $7
        if !protocol.blank?
          html_attrs = tag_options(options.stringify_keys) || ""
          "#{before}<a href=\"#{html_escape(url)}\"#{html_attrs}>#{html_escape(url)}</a>"
        else
          all
        end
      end
    end

    private


    def target_tag(options)
      target_option = options[:target]
      if target_option.blank?
        ""
      else
        "target=\"#{html_escape(target_option)}\""
      end
    end

  end
end
