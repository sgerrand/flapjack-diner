require 'httparty'
require 'json'
require 'uri'

require "flapjack-diner/version"

module Flapjack
  module Diner

    include HTTParty
    format :json

    class << self

      # NB: clients will need to handle any exceptions caused by,
      # e.g., network failures or non-parseable JSON data.

      def entities
        parsed( get("/entities") )
      end

      def checks(entity)
        args = prepare(:entity => {:value => entity, :required => true})

        perform_get_request('checks', args)
      end

      def status(entity, options = {})
        args = prepare(:entity     => {:value => entity, :required => true},
                       :check      => {:value => options[:check]})

        perform_get_request('status', args)
      end

      def acknowledge!(entity, check, options = {})
        args = prepare(:entity   => {:value => entity, :required => true},
                       :check    => {:value => check, :required => true})
        query = prepare(:summary => {:value => options[:summary]})

        path = "/acknowledgments/#{args[:entity]}/#{args[:check]}"
        params = query.collect{|k,v| "#{k.to_s}=#{v}"}.join('&')

        response = post(path, :body => params)
        response.code == 204
      end

      def create_scheduled_maintenance!(entity, check, start_time, duration, options = {})
        args = prepare(:entity     => {:value => entity, :required => true},
                       :check      => {:value => check, :required => true})
        query = prepare(:start_time => {:value => start_time, :required => true, :class => Time},
                        :duration   => {:value => duration, :required => true, :class => Integer},
                        :summary    => {:value => options[:summary]})

        path ="/scheduled_maintenances/#{args[:entity]}/#{args[:check]}"
        params = query.collect{|k,v| "#{k.to_s}=#{v}"}.join('&')

        response = post(path, :body => params)
        response.code == 204
      end

      def scheduled_maintenances(entity, options = {})
        args = prepare(:entity      => {:value => entity, :required => true},
                       :check       => {:value => options[:check]})
        query = prepare(:start_time => {:value => options[:start_time], :class => Time},
                        :end_time   => {:value => options[:end_time], :class => Time})

        perform_get_request('scheduled_maintenances', args, query)
      end

      def unscheduled_maintenances(entity, options = {})
        args = prepare(:entity      => {:value => entity, :required => true},
                       :check       => {:value => options[:check]})
        query = prepare(:start_time => {:value => options[:start_time], :class => Time},
                        :end_time   => {:value => options[:end_time], :class => Time})

        perform_get_request('unscheduled_maintenances', args, query)
      end

      def outages(entity, options = {})
        args = prepare(:entity      => {:value => entity, :required => true},
                       :check       => {:value => options[:check]})
        query = prepare(:start_time => {:value => options[:start_time], :class => Time},
                        :end_time   => {:value => options[:end_time], :class => Time})

        perform_get_request('outages', args, query)
      end

      def downtime(entity, options = {})
        args = prepare(:entity      => {:value => entity, :required => true},
                       :check       => {:value => options[:check]})
        query = prepare(:start_time => {:value => options[:start_time], :class => Time},
                        :end_time   => {:value => options[:end_time], :class => Time})

        perform_get_request('downtime', args, query)
      end

    private

      def perform_get_request(action, args, query = nil)
        prepare_request(action, args, query) do |path, params|
          parsed( get(build_uri(path, params).request_uri) )
        end
      end

      def prepare_request(action, args, query = nil)
        path = ["/#{action}", args[:entity], args[:check]].compact.join('/')
        params = query.collect{|k,v| "#{k.to_s}=#{v}"}.join('&') if query
        yield path, params
      end

      def protocol_host_port
        self.base_uri =~ /$(?:(https?):\/\/)?([a-zA-Z0-9][a-zA-Z0-9\.\-]*[a-zA-Z0-9])(?::\d+)?/i
        protocol = ($1 || 'http').downcase
        host = $2
        port = $3 || ('https'.eql?(protocol) ? 443 : 80)

        [protocol, host, port]
      end

      def build_uri(path, params)
        pr, ho, po = protocol_host_port
        URI::HTTP.build(:protocol => pr, :host => ho, :port => po,
          :path => path, :query => (params && params.empty? ? nil : params))
      end

      def prepare(data = {})
        data.inject({}) do |result, (k, v)|
          if value = ensure_valid_value(k,v)
            result[k] = URI.escape(value.respond_to?(:iso8601) ? value.iso8601 : value.to_s)
          end
          result
        end
      end

      def ensure_valid_value(key, value)
        unless result = value[:value]
          raise "'#{key}' is required" if value[:required]
          return
        end
        expected_class = value[:class]
        if Time.eql?(expected_class)
          raise "'#{key}' should contain some kind of time object." unless result.respond_to?(:iso8601)
        else
          raise "'#{key}' must be a #{expected_class}" unless expected_class.nil? || result.is_a?(expected_class)
        end
        result
      end

      def parsed(response)
        return unless response && response.respond_to?(:parsed_response)
        response.parsed_response
      end

    end

  end
end
