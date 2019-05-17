# encoding: UTF-8
# frozen_string_literal: true

module Dump
  # Get rails app root (Rails.root or RAILS_ROOT or fail)
  module RailsRoot
    def rails_root
      case
      when defined?(Rails)
        Rails.root
      when defined?(RAILS_ROOT)
        RAILS_ROOT
      else
        fail 'Unknown rails app root'
      end.to_s
    end

    Dump.extend RailsRoot
  end
end
