require 'fog/rackspace'
require 'fog/rackspace/authentication'
require 'fog/storage'

module Fog
  module Storage
    class Rackspace < Fog::Service

      requires :rackspace_api_key, :rackspace_username
      recognizes :rackspace_auth_url, :rackspace_servicenet, :rackspace_cdn_ssl, :persistent, :rackspace_region
      recognizes :rackspace_temp_url_key, :rackspace_storage_url, :rackspace_cdn_url

      model_path 'fog/rackspace/models/storage'
      model       :directory
      collection  :directories
      model       :file
      collection  :files

      request_path 'fog/rackspace/requests/storage'
      request :copy_object
      request :delete_container
      request :delete_object
      request :get_container
      request :get_containers
      request :get_object
      request :get_object_https_url
      request :head_container
      request :head_containers
      request :head_object
      request :put_container
      request :put_object
      request :put_object_manifest
      request :post_set_meta_temp_url_key

      module Utils

        def cdn
          @cdn ||= Fog::CDN.new(
            :provider           => 'Rackspace',
            :rackspace_api_key  => @rackspace_api_key,
            :rackspace_auth_url => @rackspace_auth_url,
            :rackspace_cdn_url => @rackspace_cdn_url,
            :rackspace_username => @rackspace_username,
            :rackspace_region => @rackspace_region
          )
          if @cdn.enabled?
            @cdn
          end
        end

      end      

      class Mock
        include Utils
        include Fog::Rackspace::Authentication
        
        def self.data
          @data ||= Hash.new do |hash, key|
            hash[key] = {}
          end
        end

        def self.reset
          @data = nil
        end

        def initialize(options={})
          require 'mime/types'
          @rackspace_api_key = options[:rackspace_api_key]
          @rackspace_username = options[:rackspace_username]
        end

        def data
          self.class.data[@rackspace_username]
        end

        def reset_data
          self.class.data.delete(@rackspace_username)
        end

      end

      class Real
        include Utils
        include Fog::Rackspace::Authentication
        
        attr_reader :rackspace_cdn_ssl

        def initialize(options={})
          require 'mime/types'
          @rackspace_api_key = options[:rackspace_api_key]
          @rackspace_username = options[:rackspace_username]
          @rackspace_cdn_ssl = options[:rackspace_cdn_ssl]
          @rackspace_auth_url = options[:rackspace_auth_url]
          @rackspace_servicenet = options[:rackspace_servicenet]
          @rackspace_auth_token = options[:rackspace_auth_token]
          @rackspace_storage_url = options[:rackspace_storage_url]
          @rackspace_cdn_url = options[:rackspace_cdn_url]          
          @rackspace_region = options[:rackspace_region] || :dfw
          @rackspace_temp_url_key = options[:rackspace_temp_url_key]
          @rackspace_must_reauthenticate = false
          @connection_options     = options[:connection_options] || {}

          authenticate
          @persistent = options[:persistent] || false
          Excon.defaults[:ssl_verify_peer] = false if service_net?
          @connection = Fog::Connection.new(endpoint_uri, @persistent, @connection_options)
        end        

        def reload
          @connection.reset
        end

        def request(params, parse_json = true, &block)
          begin
            response = @connection.request(params.merge({
              :headers  => {
                'Content-Type' => 'application/json',
                'X-Auth-Token' => @auth_token
              }.merge!(params[:headers] || {}),
              :host     => endpoint_uri.host,
              :path     => "#{endpoint_uri.path}/#{params[:path]}",
            }), &block)
          rescue Excon::Errors::Unauthorized => error
            if error.response.body != 'Bad username or password' # token expiration
              @rackspace_must_reauthenticate = true
              authenticate
              retry
            else # bad credentials
              raise error
            end
          rescue Excon::Errors::HTTPStatusError => error
            raise case error
            when Excon::Errors::NotFound
              Fog::Storage::Rackspace::NotFound.slurp(error)
            else
              error
            end
          end
          if !response.body.empty? && parse_json && response.headers['Content-Type'] =~ %r{application/json}
            response.body = Fog::JSON.decode(response.body)
          end
          response
        end

        def service_net?
          @rackspace_servicenet == true
        end        
        
        def authenticate
          if @rackspace_must_reauthenticate || @rackspace_auth_token.nil?
            options = {
              :rackspace_api_key  => @rackspace_api_key,
              :rackspace_username => @rackspace_username,
              :rackspace_auth_url => @rackspace_auth_url
            }            
            @uri = self.send authentication_method, options
          else
            @auth_token = @rackspace_auth_token
            @uri = URI.parse(@rackspace_storage_url)
          end
        end
        
        def endpoint_uri(service_endpoint_url=nil)
          return @uri if @uri
          
          url  = @rackspace_storage_url || service_endpoint_url          
          unless url
            if v1_authentication?
              raise "Service Endpoint must be specified via :rackspace_storage_url parameter"
            else
              url = @identity_service.service_catalog.get_endpoint(:cloudFiles, @rackspace_region)            
            end
          end          
          
          @uri = URI.parse url
          @uri.host = "snet-#{@uri.host}" if service_net?
          @uri
        end
    
        private 
        
        def authenticate_v1(options)
          credentials = Fog::Rackspace.authenticate(options, @connection_options)
          @auth_token = credentials['X-Auth-Token']
          endpoint_uri credentials['X-Storage-Url']
        end
    
      end
    end
  end
end
